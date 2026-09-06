`timescale 1ns/1ps

module tb_counter;

// Testbench-driven input signals.
reg clk;
reg rst;
reg load;
reg [3:0] data_in;
reg en;
reg up_down;
// DUT output signal.
wire [3:0] count;

// Device Under Test (DUT) instantiation.
counter dut (
    .clk(clk),
    .rst(rst),
    .load(load),
    .data_in(data_in),
    .en(en),
    .up_down(up_down),
    .count(count)
);

// Initialize clock.
initial begin
    clk = 1'b0;
end

// Free-running clock generator: 10 ns period.
always #5 clk = ~clk;

// Reusable checker for expected counter value.
task automatic check_count(input [3:0] expected, input string name);
begin
    if (count === expected) begin
        $display("PASS: %s | expected=%0d actual=%0d time=%0t", name, expected, count, $time);
    end else begin
        $display("FAIL: %s | expected=%0d actual=%0d time=%0t", name, expected, count, $time);
    end
end
endtask

// Main stimulus sequence.
initial begin
    // Init inputs; count is X until first reset/clocked assignment.
    rst = 1'b0;
    load = 1'b0;
    data_in = 4'd0;
    en = 1'b0;
    up_down = 1'b1;

    // 1-3) Reset and LOAD check: async reset pulse, then load 10.
    rst = 1'b1;
    @(posedge clk);
    #1;
    rst = 1'b0;

    load = 1'b1;
    data_in = 4'd10;
    @(posedge clk);
    #1;
    load = 1'b0;
    check_count(4'd10, "Load value 10");

    // 4) Count up with wrap-around: 10 -> 13 -> 0.
    en = 1'b1;
    up_down = 1'b1;
    repeat (3) begin
        @(posedge clk);
        #1;
    end
    check_count(4'd13, "Count up 3 clocks from 10 to 13");

    repeat (3) begin
        @(posedge clk);
        #1;
    end
    check_count(4'd0, "Count up 3 more clocks with wrap 15->0");

    // 5) Hold value when en=0.
    en = 1'b0;
    repeat (2) begin
        @(posedge clk);
        #1;
    end
    check_count(4'd0, "Hold value when en=0");

    // 6) Count down with wrap-around: 0 -> 15.
    en = 1'b1;
    up_down = 1'b0;
    @(posedge clk);
    #1;
    check_count(4'd15, "Count down wrap 0->15");

    // 7) Priority check: load over en (both asserted together).
    load = 1'b1;
    data_in = 4'd5;
    en = 1'b1;
    up_down = 1'b1;
    @(posedge clk);
    #1;
    check_count(4'd5, "Priority load over en");
    load = 1'b0;

    // Bonus: non-boundary down-count case 8 -> 7.
    load = 1'b1;
    data_in = 4'd8;
    @(posedge clk);
    #1;
    load = 1'b0;
    up_down = 1'b0;
    en = 1'b1;
    @(posedge clk);
    #1;
    check_count(4'd7, "Bonus: down-count 8->7");

    // End simulation.
    $finish;
end

endmodule
