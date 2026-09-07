// debounce_filter.v
// Generic debounce filter for a noisy multi-bit input coming from
// physical buttons (part of ДЗ item 1.3 for lesson 6).
//
// Two stages:
//   1) 2-flop synchronizer to avoid metastability on the async input.
//   2) Stability counter: the synchronized sample must stay unchanged
//      for STABLE_CYCLES consecutive clocks before it is accepted and
//      forwarded on clean_out. Any change resets the counter.
//
// `valid` pulses for exactly ONE clock when clean_out is updated to a
// genuinely new value -- a real button stays pressed (held level) for
// many clock cycles, so a downstream FSM must react to this one-shot
// "new digit accepted" event rather than to the held level itself.

module debounce_filter #(
    parameter WIDTH         = 4,
    parameter STABLE_CYCLES = 3
) (
    input  wire             clk,
    input  wire             rst,        // asynchronous reset, active high
    input  wire [WIDTH-1:0] noisy_in,
    output reg  [WIDTH-1:0] clean_out,
    output reg              valid       // one-cycle pulse: new digit accepted
);

    // ---- Stage A: 2-flop synchronizer ----
    reg [WIDTH-1:0] sync0, sync1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync0 <= {WIDTH{1'b0}};
            sync1 <= {WIDTH{1'b0}};
        end else begin
            sync0 <= noisy_in;
            sync1 <= sync0;
        end
    end

    // ---- Stage B: stability counter + accept ----
    reg [WIDTH-1:0]           last_sample;
    reg [$clog2(STABLE_CYCLES+1)-1:0] stable_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            last_sample  <= {WIDTH{1'b0}};
            stable_count <= 0;
            clean_out    <= {WIDTH{1'b0}};
            valid        <= 1'b0;
        end else begin
            valid <= 1'b0; // default: no event this cycle
            if (sync1 == last_sample) begin
                if (stable_count < STABLE_CYCLES) begin
                    stable_count <= stable_count + 1'b1;
                end else if (clean_out != sync1) begin
                    clean_out <= sync1;
                    valid     <= 1'b1; // new stable digit accepted
                end
            end else begin
                last_sample  <= sync1;
                stable_count <= 0;
            end
        end
    end

endmodule
