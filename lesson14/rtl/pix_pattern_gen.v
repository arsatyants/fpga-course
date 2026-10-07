// pix_pattern_gen.v
// Синтезована копія моделі джерела з lesson12/tb/pix_source.vh -- щоб на платі
// без камери на JP1 frame_rx_axis отримував справжній потік кадрів.
//
// Формат той самий, що в testbench:
//   * кадр 320x200, 1 байт/такт pix_clk; рядок = 320 тактів pix_valid=1 + H_BLANK тактів 0;
//   * між кадрами V_BLANK тактів pix_valid=0;
//   * pix_fsync=1 разом із першим пікселем кадру;
//   * піксель = (x + 2*y + 7*frame) & 8'hFF -- номер кадру закодовано в даних;
//   * у бланкінгу на шині сміття (LFSR) -- приймач має його ігнорувати.
// Генератор працює з моменту конфігурації і нікого не чекає, як зовнішня камера.

module pix_pattern_gen #(
    parameter FRAME_W = 320,
    parameter FRAME_H = 200,
    parameter H_BLANK = 40,
    parameter V_BLANK = 2000
) (
    input  wire       pix_clk,
    output reg  [7:0] pix_data  = 8'h00,
    output reg        pix_valid = 1'b0,
    output reg        pix_fsync = 1'b0
);

    localparam integer LINE_LEN = FRAME_W + H_BLANK;

    reg [11:0] hcnt  = 0;          // 0..LINE_LEN-1 (а у вертикальному бланкінгу -- лічильник V_BLANK)
    reg [11:0] vcnt  = 0;          // 0..FRAME_H-1 -- рядок, FRAME_H -- вертикальний бланкінг
    reg [7:0]  frame = 0;          // номер кадру mod 256
    reg [7:0]  base  = 0;          // (2*y + 7*frame) & 0xFF для поточного рядка
    reg [7:0]  pix   = 0;          // base + x
    reg [15:0] lfsr  = 16'hACE1;

    wire in_vblank = (vcnt == FRAME_H);
    wire active    = !in_vblank && (hcnt < FRAME_W);

    always @(posedge pix_clk) begin
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

        // ---- вихід (реєстрований) ----
        pix_valid <= active;
        pix_fsync <= active && (hcnt == 0) && (vcnt == 0);
        pix_data  <= active ? pix : lfsr[7:0];

        // ---- лічильники ----
        if (in_vblank) begin
            if (hcnt == V_BLANK - 1) begin
                hcnt  <= 0;
                vcnt  <= 0;
                frame <= frame + 1'b1;
                base  <= frame + 1'b1 + ((frame + 1'b1) << 1) + ((frame + 1'b1) << 2); // 7*(frame+1)
                pix   <= frame + 1'b1 + ((frame + 1'b1) << 1) + ((frame + 1'b1) << 2);
            end else
                hcnt <= hcnt + 1'b1;
        end else if (hcnt == LINE_LEN - 1) begin
            hcnt <= 0;
            vcnt <= vcnt + 1'b1;
            base <= base + 8'd2;
            pix  <= base + 8'd2;
        end else begin
            hcnt <= hcnt + 1'b1;
            if (active) pix <= pix + 1'b1;
        end
    end

endmodule
