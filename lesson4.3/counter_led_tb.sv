`timescale 1ns / 1ps

module counter_led_tb;

    logic       clk;
    logic       reset;
    logic [3:0] led;
    logic [3:0] expected;

    counter_led dut (
        .clk   (clk),
        .reset (reset),
        .led   (led)
    );

    // 10ns period clock
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1;
        repeat (2) @(posedge clk);
        #1;
        if (led !== 4'b0000)
            $error("After reset: expected led=0000, got %b", led);

        reset = 0;
        expected = 4'b0000;

        // Two full wraps: each posedge increments led by 1, wrapping 15 -> 0.
        repeat (32) begin
            @(posedge clk);
            #1;
            expected = expected + 1'b1;
            if (led !== expected)
                $error("t=%0t: expected led=%b, got %b", $time, expected, led);
            $display("t=%0t count=%0d led=%b", $time, expected, led);
        end

        // Mid-count reset check
        @(posedge clk);
        reset = 1;
        @(posedge clk);
        #1;
        if (led !== 4'b0000)
            $error("Mid-count reset: expected led=0000, got %b", led);
        reset = 0;

        $display("counter_led_tb: all checks passed");
        $finish;
    end

endmodule
