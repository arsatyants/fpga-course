// frame_rx_axis.v
// Приймач кадру 8 біт/такт ззовні дизайну -> AXI4-Stream master 32 біт
// (для AXI DMA S_AXIS_S2MM).
//
// ЗОВНІШНІЙ ІНТЕРФЕЙС (паралельний "камерний", як DVP/BT.656 без вбудованих кодів):
//   pix_clk      -- такт джерела; дані змінюються по спаду, захоплюються по фронту
//   pix_data[7:0]-- піксель (1 байт)
//   pix_valid    -- байт на pix_data дійсний у цьому такті (DE / HREF);
//                   у бланкінгу (між рядками/кадрами) = 0
//   pix_fsync    -- маркер початку кадру: = 1 разом із ПЕРШИМ пікселем кадру
//                   (pix_valid=1). Без нього неможливо знайти межу кадру,
//                   якщо приймач увімкнено посеред потоку.
//
// КЕРУВАННЯ (домен aclk):
//   start        -- рівень від AXI GPIO. Фронт 0->1 "озброює" приймач на ОДИН кадр.
//                   До цього (і після прийому кадру) вхідні порти ігноруються.
//   status[0]    -- busy: приймач чекає/приймає кадр
//   status[1]    -- overflow: FIFO був повний і байти втрачено (sticky до нового start)
//
// ВСЕРЕДИНІ: пакування 4 байт -> 32-бітне слово (little-endian: перший піксель
// у [7:0]), і асинхронний FIFO pix_clk -> aclk (синхронізація доменів).
// TLAST = 1 на останньому слові кадру (FRAME_W*FRAME_H/4-му), щоб DMA S2MM
// завершив транзакцію рівно на межі кадру.
//
// Розрахунок пам'яті: 320*200 = 64000 байт = 16000 32-бітних слів.
// axi4_full_ram: MEM_DEPTH = 16000, ADDR_WIDTH = 16 (2^16 = 65536 байт >= 64000).

module frame_rx_axis #(
    parameter FRAME_W     = 320,
    parameter FRAME_H     = 200,
    parameter FIFO_ADDR_W = 4        // глибина FIFO = 16 слів
) (
    // ---- зовнішній піксельний інтерфейс ----
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 pix_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 40000000" *)
    input  wire        pix_clk,
    input  wire [7:0]  pix_data,
    input  wire        pix_valid,
    input  wire        pix_fsync,

    // ---- системний домен ----
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axis, ASSOCIATED_RESET aresetn" *)
    input  wire        aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        aresetn,

    input  wire        start,
    output wire [1:0]  status,

    // ---- AXI4-Stream master ----
    output wire [31:0] m_axis_tdata,
    output wire [3:0]  m_axis_tkeep,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);

    localparam integer PIXELS = FRAME_W * FRAME_H;    // 64000 байт
    localparam integer PCNT_W = $clog2(PIXELS);

    // ==================================================================
    // Скидання в домені pix_clk: асинхронне встановлення, синхронне зняття
    // ==================================================================
    (* ASYNC_REG = "TRUE" *) reg [1:0] prst_sync;
    always @(posedge pix_clk or negedge aresetn) begin
        if (!aresetn) prst_sync <= 2'b00;
        else          prst_sync <= {prst_sync[0], 1'b1};
    end
    wire pix_rst_n = prst_sync[1];

    // ==================================================================
    // start (aclk, рівень з GPIO) -> домен pix_clk, детектор фронту
    // ==================================================================
    (* ASYNC_REG = "TRUE" *) reg [1:0] start_sync;
    reg start_d;
    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n) begin
            start_sync <= 2'b00;
            start_d    <= 1'b0;
        end else begin
            start_sync <= {start_sync[0], start};
            start_d    <= start_sync[1];
        end
    end
    wire start_rise = start_sync[1] && !start_d;

    // ==================================================================
    // Вхідні регістри (IOB) -- захоплення зовнішніх даних по фронту pix_clk
    // ==================================================================
    (* IOB = "TRUE" *) reg [7:0] in_data;
    (* IOB = "TRUE" *) reg       in_valid;
    (* IOB = "TRUE" *) reg       in_fsync;
    always @(posedge pix_clk) begin
        in_data  <= pix_data;
        in_valid <= pix_valid;
        in_fsync <= pix_fsync;
    end

    // ==================================================================
    // Автомат прийому кадру + пакування 4 байт у слово
    // ==================================================================
    localparam [1:0] S_IDLE = 2'd0,   // ігнорує вхід
                     S_ARM  = 2'd1,   // чекає початку кадру (fsync)
                     S_CAPT = 2'd2;   // приймає PIXELS байт

    reg [1:0]        state;
    reg [PCNT_W-1:0] pix_cnt;          // номер поточного пікселя в кадрі
    reg [23:0]       shreg;            // три попередні байти слова
    reg              fifo_wr;
    reg [32:0]       fifo_din;         // {tlast, tdata}
    reg              overflow;
    wire             fifo_full;

    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n) begin
            state    <= S_IDLE;
            pix_cnt  <= 0;
            shreg    <= 24'd0;
            fifo_wr  <= 1'b0;
            fifo_din <= 33'd0;
            overflow <= 1'b0;
        end else begin
            fifo_wr <= 1'b0;
            if (fifo_wr && fifo_full)
                overflow <= 1'b1;

            case (state)
                S_IDLE: begin
                    if (start_rise) begin
                        overflow <= 1'b0;
                        state    <= S_ARM;
                    end
                end

                S_ARM: begin
                    if (in_valid && in_fsync) begin
                        shreg   <= {in_data, shreg[23:8]};
                        pix_cnt <= 1;
                        state   <= S_CAPT;
                    end
                end

                S_CAPT: begin
                    if (in_valid) begin
                        shreg   <= {in_data, shreg[23:8]};
                        pix_cnt <= pix_cnt + 1'b1;
                        if (pix_cnt[1:0] == 2'd3) begin
                            fifo_wr  <= 1'b1;
                            fifo_din <= {(pix_cnt == PIXELS-1), in_data, shreg};
                        end
                        if (pix_cnt == PIXELS-1)
                            state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // ==================================================================
    // FIFO pix_clk -> aclk
    // ==================================================================
    wire [32:0] fifo_dout;
    wire        fifo_empty;

    async_fifo #(
        .DATA_W (33),
        .ADDR_W (FIFO_ADDR_W)
    ) u_fifo (
        .wr_clk   (pix_clk),
        .wr_rst_n (pix_rst_n),
        .wr_en    (fifo_wr),
        .wr_data  (fifo_din),
        .wr_full  (fifo_full),

        .rd_clk   (aclk),
        .rd_rst_n (aresetn),
        .rd_en    (m_axis_tready),
        .rd_data  (fifo_dout),
        .rd_empty (fifo_empty)
    );

    assign m_axis_tvalid = !fifo_empty;
    assign m_axis_tdata  = fifo_dout[31:0];
    assign m_axis_tlast  = fifo_dout[32];
    assign m_axis_tkeep  = 4'hF;

    // ==================================================================
    // Статус -> домен aclk (для AXI GPIO)
    // ==================================================================
    (* ASYNC_REG = "TRUE" *) reg [1:0] busy_sync, ovf_sync;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            busy_sync <= 2'b00;
            ovf_sync  <= 2'b00;
        end else begin
            busy_sync <= {busy_sync[0], (state != S_IDLE)};
            ovf_sync  <= {ovf_sync[0],  overflow};
        end
    end
    assign status = {ovf_sync[1], busy_sync[1] || !fifo_empty};

endmodule
