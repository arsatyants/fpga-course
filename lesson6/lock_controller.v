// lock_controller.v
// ДЗ Заняття 6, Частина 1: three-digit code lock controller.
// Exactly three always-blocks for the FSM (state register, next-state
// logic, output logic) as required; the debounce filter is a separate
// module with its own always-blocks and is not part of that count.

module lock_controller (
    input  wire       clk,
    input  wire       rst,        // asynchronous reset, active high
    input  wire [3:0] digit_in,   // raw signal straight from physical buttons
    output reg        unlocked_led
);

    // The 3-digit code. Change these three values to set a different code.
    localparam [3:0] CODE0 = 4'd5;
    localparam [3:0] CODE1 = 4'd3;
    localparam [3:0] CODE2 = 4'd7;

    // States
    localparam [1:0] LOCKED   = 2'd0;
    localparam [1:0] WAIT_D2  = 2'd1;
    localparam [1:0] WAIT_D3  = 2'd2;
    localparam [1:0] UNLOCKED = 2'd3;

    // ---- Debounce filter for digit_in (item 1.3) ----
    // digit_valid pulses for one clock when a new stable digit is
    // accepted; a real button holds its level for many clocks, so the
    // FSM below reacts to that one-shot event, not to the raw level.
    wire [3:0] digit_clean;
    wire       digit_valid;

    debounce_filter #(
        .WIDTH(4),
        .STABLE_CYCLES(3)
    ) u_debounce (
        .clk(clk),
        .rst(rst),
        .noisy_in(digit_in),
        .clean_out(digit_clean),
        .valid(digit_valid)
    );

    reg [1:0] state, next_state;

    // ---- Block 1: state register (memory only) ----
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= LOCKED;
        else
            state <= next_state;
    end

    // ---- Block 2: next-state logic (transitions, uses debounced digit) ----
    // Only acts on digit_valid (one-shot "new digit accepted" event) --
    // otherwise a held button level would be re-evaluated every clock
    // and immediately bounce back to LOCKED as soon as the FSM moves
    // to the next WAIT_ state while the same old digit is still held.
    always @(*) begin
        next_state = state;  // default -> avoids an unintended latch
        if (digit_valid) begin
            case (state)
                LOCKED:
                    if (digit_clean == CODE0) next_state = WAIT_D2;
                    else                      next_state = LOCKED;
                WAIT_D2:
                    if (digit_clean == CODE1) next_state = WAIT_D3;
                    else                      next_state = LOCKED;
                WAIT_D3:
                    if (digit_clean == CODE2) next_state = UNLOCKED;
                    else                      next_state = LOCKED;
                UNLOCKED:
                    next_state = UNLOCKED;
                default:
                    next_state = LOCKED;
            endcase
        end
    end

    // ---- Block 3: output logic (Moore -- depends only on state) ----
    always @(*) begin
        unlocked_led = (state == UNLOCKED);
    end

endmodule
