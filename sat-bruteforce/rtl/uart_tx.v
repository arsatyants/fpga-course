// UART TX 8N1. CLKS_PER_BIT = f_clk / baud (50 МГц / 115200 = 434).
module uart_tx #(
    parameter CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       send,      // импульс при !busy
    input  wire [7:0] data,
    output reg        tx,
    output wire       busy
);
    reg [15:0] div;
    reg [3:0]  bitn;             // 0 = старт, 1..8 = данные, 9 = стоп
    reg [8:0]  sh;
    reg        act;
    assign busy = act;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1; act <= 0; div <= 0; bitn <= 0;
        end else if (!act) begin
            tx <= 1;
            if (send) begin
                act <= 1; sh <= {1'b1, data}; tx <= 0; div <= 0; bitn <= 0;
            end
        end else if (div == CLKS_PER_BIT - 1) begin
            div <= 0;
            if (bitn == 9) begin
                act <= 0; tx <= 1;
            end else begin
                tx <= sh[0]; sh <= {1'b1, sh[8:1]}; bitn <= bitn + 1'b1;
            end
        end else begin
            div <= div + 1'b1;
        end
    end
endmodule
