// alu.v
// ДЗ Заняття 7, Частина 2: simple ALU used only as an STA/Timing example.
// Inputs ARE registered (a_reg/b_reg/op_reg), the same pattern used in
// counter.v -- every path in the design is register-to-register, so a
// one-line .xdc (just create_clock) is enough for a meaningful WNS,
// with no "Unconstrained Paths" warnings in the Methodology report.

module alu (
    input  wire       clk,
    input  wire       rst,        // asynchronous reset, active high
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [1:0] op,         // 00=add, 01=sub, 10=and, 11=or
    input  wire       oe,         // output enable
    output reg  [3:0] result
);

    // ---- Stage 0: registered inputs ----
    reg [3:0] a_reg, b_reg;
    reg [1:0] op_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_reg  <= 4'd0;
            b_reg  <= 4'd0;
            op_reg <= 2'd0;
        end else begin
            a_reg  <= a;
            b_reg  <= b;
            op_reg <= op;
        end
    end

    // ---- Stage 1: ALU operation + registered output ----
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 4'd0;
        end else if (oe) begin
            case (op_reg)
                2'b00: result <= a_reg + b_reg;
                2'b01: result <= a_reg - b_reg;
                2'b10: result <= a_reg & b_reg;
                2'b11: result <= a_reg | b_reg;
            endcase
        end
    end

endmodule
