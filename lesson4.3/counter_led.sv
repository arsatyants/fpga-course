`timescale 1ns / 1ps

// 4-bit counter: increments each clk edge, wraps 15 -> 0.
// led[3:0] is the binary pattern for LEDs, one bit per LED.
module counter_led (
    input  logic       clk,
    input  logic       reset,
    output logic [3:0] led
);

    always_ff @(posedge clk) begin
        if (reset)
            led <= 4'b0000;
        else
            led <= led + 1'b1;
    end

endmodule
