`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/30/2026 09:47:41 PM
// Design Name: 
// Module Name: counter
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


//Count incremenys synchroiniously on clk
//Reset clears the counter when reset is HIGH
//no latches  because it is clocked
module counter(
   input clk,
   input reset,
   output reg[3:0] count 
);
always @(posedge  clk)begin
    if(reset) begin
      count <= 4'b0000; //reset to 0
    end
    else begin
      count <= count + 1; //increment clock edge
    end
end
endmodule 
