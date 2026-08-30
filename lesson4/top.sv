`timescale 1ns / 1ps

module top (
    input  logic         clk,
    input  logic         reset,
    input  logic         d,
    output logic [7:0]   leds,
    output logic         q,
    output logic         heartbeat  // onboard PL_LED1 (P15) - JTAG/clock sanity check
);

    logic [3:0] count;
    logic       slow_clk;
    logic [7:0] dec_out;

    clk_div #(
        .DIVIDER (25_000_000)  // 50MHz / (2*25M) = 1Hz
    ) u_clk_div (
        .clk_in  (clk),
        .reset   (reset),
        .clk_out (slow_clk)
    );

    counter u_counter (
        .clk   (slow_clk),
        .reset (reset),
        .count (count)
    );

    decoder #(
        .WIDTH (3)
    ) u_decoder (
        .en  (1'b1),  // always enabled - no external pin dependency
        .sel (count[2:0]),
        .out (dec_out)
    );

    // LED module is common-anode / active-low: invert so exactly one LED lights.
    assign leds = ~dec_out;
    assign heartbeat = slow_clk;

    latch_fix u_latch_fix (
        .clk  (clk),
        .data (d),
        .q    (q)
    );

endmodule
