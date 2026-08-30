`timescale 1ns / 1ps

module decoder #(
    parameter WIDTH = 8
) (
    input  logic                    en,
    input  logic [WIDTH-1:0]        sel,
    output logic [(1<<WIDTH)-1:0]   out
);

    always_comb begin
        out = '0;
        if (en)
            out[sel] = 1'b1;
    end

endmodule
