`timescale 1ns/1ps
// 4-bit up/down counter with async reset and sync load.
module counter (
    // Clock input.
    input wire clk,
    // Asynchronous active-high reset.
    input wire rst,
    // Synchronous load enable.
    input wire load,
    // 4-bit value to load when load=1.
    input wire [3:0] data_in,
    // Count enable.
    input wire en,
    // Direction: 1=up, 0=down.
    input wire up_down,
    // Current counter value.
    output reg [3:0] count
);

// Priority order:
// 1) rst (async) -> count=0
// 2) load (sync) -> count=data_in
// 3) en   (sync) -> count+1 or count-1
always @(posedge clk or posedge rst) begin
    if (rst) begin
        count <= 4'd0;
    end else if (load) begin
        count <= data_in;
    end else if (en) begin
        if (up_down) begin
            count <= count + 4'd1;
        end else begin
            count <= count - 4'd1;
        end
    end
    // If load=0 and en=0, hold previous value.
end

endmodule
