// tb_lock_controller.v
// Testbench for lock_controller.v (ДЗ Заняття 6, item 1.2):
//   - correct 3-digit sequence, checking EACH transition separately
//     (LOCKED->WAIT_D2, WAIT_D2->WAIT_D3, WAIT_D3->UNLOCKED)
//   - error scenario: a wrong digit on any step returns to LOCKED
//
// digit_in now passes through debounce_filter (STABLE_CYCLES=3, plus a
// 2-flop synchronizer), so after changing digit_in the testbench must
// hold it stable for several clocks before the FSM reacts. WAIT_CYCLES
// below is generous on purpose.
//
// Console run (Vivado XSim):
//     xvlog debounce_filter.v lock_controller.v tb_lock_controller.v
//     xelab tb_lock_controller -s tb_sim
//     xsim tb_sim -R

module tb_lock_controller;

    localparam WAIT_CYCLES = 12; // >> debounce latency (~6 cycles), safety margin

    reg        clk;
    reg        rst;
    reg  [3:0] digit_in;
    wire       unlocked_led;

    lock_controller dut (
        .clk(clk), .rst(rst),
        .digit_in(digit_in), .unlocked_led(unlocked_led)
    );

    // ---- Clock generator ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Self-checking task: apply one digit, wait for debounce+FSM, check state ----
    task automatic check_transition;
        input [3:0] digit_val;
        input [1:0] expected_state;
        input [8*40-1:0] step_name;  // fixed-width "string" (classic Verilog has no string type)
        integer i;
        begin
            digit_in = digit_val;
            for (i = 0; i < WAIT_CYCLES; i = i + 1) begin
                @(posedge clk); #1;
            end
            if (dut.state === expected_state)
                $display("[%0t ns] PASS: %0s -> state=%0d", $time, step_name, dut.state);
            else
                $display("[%0t ns] FAIL: %0s -> expected %0d, got %0d", $time, step_name, expected_state, dut.state);
        end
    endtask

    initial begin
        // ---- Reset ----
        rst = 1; digit_in = 4'd0;
        @(posedge clk); #1;
        rst = 0;
        $display("[%0t ns] after reset: state=%0d (expect LOCKED=0)", $time, dut.state);

        // ---- Scenario 1: correct sequence -> UNLOCKED ----
        check_transition(dut.CODE0, dut.WAIT_D2,  "digit1 correct");
        check_transition(dut.CODE1, dut.WAIT_D3,  "digit2 correct");
        check_transition(dut.CODE2, dut.UNLOCKED, "digit3 correct");
        if (unlocked_led === 1'b1)
            $display("[%0t ns] PASS: unlocked_led=1 after correct sequence", $time);
        else
            $display("[%0t ns] FAIL: unlocked_led expected 1, got %0b", $time, unlocked_led);

        // ---- Reset before the error scenario ----
        rst = 1; digit_in = 4'd0;
        @(posedge clk); #1;
        rst = 0;

        // ---- Scenario 2: error on the second digit -> back to LOCKED ----
        check_transition(dut.CODE0,     dut.WAIT_D2, "digit1 correct");
        check_transition(dut.CODE1 + 1, dut.LOCKED,  "digit2 WRONG -> reset to LOCKED");

        // ---- Scenario 3: error on the first digit -> stays in LOCKED ----
        check_transition(dut.CODE0 + 1, dut.LOCKED,  "digit1 WRONG -> stays LOCKED");

        // ---- Scenario 4: error on the third digit -> back to LOCKED (not UNLOCKED) ----
        check_transition(dut.CODE0,     dut.WAIT_D2, "digit1 correct");
        check_transition(dut.CODE1,     dut.WAIT_D3, "digit2 correct");
        check_transition(dut.CODE2 + 1, dut.LOCKED,  "digit3 WRONG -> reset to LOCKED");

        $display("[%0t ns] Simulation finished", $time);
        $finish;
    end

endmodule
