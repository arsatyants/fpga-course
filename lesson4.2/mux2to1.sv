`timescale 1ns / 1ps

module mux2to1 (
    input  logic sel,
    input  logic a,
    input  logic b,
    output logic out
);

    always_comb begin
        case (sel)
            1'b0:    out = a;
            default: out = b;
        endcase
    end

endmodule
