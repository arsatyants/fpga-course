`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/30/2026 09:49:16 PM
// Design Name: 
// Module Name: latch_fix
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module latch_fix(
 input clk,
 input data,
 output reg q
);
always @(posedge clk) begin
     q <= data; //Clock-driven assignment q update only on the rising edge
end
endmodule
