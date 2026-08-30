`timescale 1ns / 1ps

// Divides clk_in down to a ~1Hz square wave on clk_out (for clk_in = 50MHz).
module clk_div #(
    parameter DIVIDER = 25_000_000  // half-period in clk_in cycles -> 1Hz out
) (
    input  logic clk_in,
    input  logic reset,
    output logic clk_out
);

    logic [$clog2(DIVIDER)-1:0] cnt;

    always_ff @(posedge clk_in) begin
        if (reset) begin
            cnt     <= '0;
            clk_out <= 1'b0;
        end else if (cnt == DIVIDER - 1) begin
            cnt     <= '0;
            clk_out <= ~clk_out;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule
