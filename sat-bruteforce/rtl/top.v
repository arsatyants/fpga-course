// Z7-Lite (XC7Z010): параллельный перебор 3-SAT на 50 МГц, результат в UART.
//
// После сброса перебор стартует сам, btn[0] — перезапуск.
// led[0]: мигает во время перебора, горит при SAT, гаснет при UNSAT.
// led[1]: горит, когда перебор закончен.
// uart_tx (115200 8N1), одна строка на запуск:
//   "SAT   x=<hex решения> cyc=<hex тактов>\r\n"  или  "UNSAT x=0... cyc=...\r\n"
// Время перебора = cyc / 50e6 с.
module top #(
    parameter LOGP         = 6,          // 64 ядра
    parameter CLKS_PER_BIT = 434,        // 50e6 / 115200
    parameter MEMFILE      = "formula.mem"
)(
    input  wire       clk_50m,
    input  wire       rst_n,
    input  wire [0:0] btn,               // активный 0
    output wire [1:0] led,
    output wire       uart_tx
);
    `include "formula_params.vh"         // localparam N, M — генерирует tools/gen_cnf.py

    // ---- сброс и кнопка: синхронизация + фронт ----
    reg [1:0] rst_s = 2'b00;
    always @(posedge clk_50m) rst_s <= {rst_s[0], rst_n};
    wire rst = ~rst_s[1];

    reg [2:0] btn_s = 3'b111;
    always @(posedge clk_50m) btn_s <= {btn_s[1:0], btn[0]};
    wire btn_press = btn_s[2] & ~btn_s[1];

    reg boot;                            // автозапуск после сброса
    always @(posedge clk_50m) boot <= rst;
    wire start = (boot & ~rst) | btn_press;

    // ---- решатель ----
    wire          busy, done, found;
    wire [N-1:0]  solution;
    wire [47:0]   cycles;

    sat_bruteforce #(.N(N), .M(M), .LOGP(LOGP), .MEMFILE(MEMFILE)) u_sat (
        .clk(clk_50m), .rst(rst), .start(start),
        .busy(busy), .done(done), .found(found),
        .solution(solution), .cycles(cycles)
    );

    // ---- светодиоды ----
    reg [23:0] blink;
    always @(posedge clk_50m) blink <= blink + 1'b1;
    assign led[0] = busy ? blink[23] : (done & found);
    assign led[1] = done;

    // ---- отчёт в UART ----
    localparam HEXN = (N + 3) / 4;
    localparam L    = 6 + 2 + HEXN + 5 + 12 + 2;

    wire [4*HEXN-1:0] sol_pad = solution;

    function [7:0] hex(input [3:0] v);
        hex = (v < 10) ? ("0" + v) : ("A" + v - 10);
    endfunction

    reg  [7:0] idx;
    reg  [7:0] ch;
    integer h;
    always @* begin
        ch = " ";
        if (idx < 6) begin
            case (idx)
                0: ch = found ? "S" : "U";
                1: ch = found ? "A" : "N";
                2: ch = found ? "T" : "S";
                3: ch = found ? " " : "A";
                4: ch = found ? " " : "T";
                default: ch = " ";
            endcase
        end else if (idx == 6) ch = "x";
        else if (idx == 7) ch = "=";
        else if (idx < 8 + HEXN) begin
            h  = 8 + HEXN - 1 - idx;             // старшая тетрада первой
            ch = hex(sol_pad[4*h +: 4]);
        end else if (idx < 8 + HEXN + 5) begin
            case (idx - (8 + HEXN))
                0: ch = " "; 1: ch = "c"; 2: ch = "y"; 3: ch = "c"; default: ch = "=";
            endcase
        end else if (idx < 8 + HEXN + 5 + 12) begin
            h  = 8 + HEXN + 5 + 12 - 1 - idx;
            ch = hex(cycles[4*h +: 4]);
        end else if (idx == L - 2) ch = 8'h0D;
        else ch = 8'h0A;
    end

    reg  sending, send, done_q;
    wire tx_busy;
    always @(posedge clk_50m) begin
        if (rst) begin
            sending <= 0; send <= 0; idx <= 0; done_q <= 0;
        end else begin
            done_q <= done;
            send   <= 0;
            if (done & ~done_q) begin
                sending <= 1; idx <= 0;
            end else if (sending && !tx_busy && !send) begin
                if (idx == L) sending <= 0;
                else begin send <= 1; end
            end
            if (send) idx <= idx + 1'b1;
        end
    end

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk_50m), .rst(rst), .send(send), .data(ch),
        .tx(uart_tx), .busy(tx_busy)
    );
endmodule
