// top.v -- lesson 14 (ILA), на основі lesson12 (кадр 320x200 через AXI DMA, MicroBlaze).
//
//   design_1 (BD з lesson12 без змін логіки) + pix_pattern_gen (джерело кадрів на 40 МГц
//   замість камери на JP1) + ILA, вставлена вручну через HDL Instantiation (ila_0 з IP Catalog,
//   5 проб -- працює і в тарифі Basic, без mark_debug / Set up Debug).
//
// Проби ILA (такт -- системні 100 МГц, aclk):
//   probe0 [7:0]  pix_data   -- піксель (домен 40 МГц, ILA семплює його на 100 МГц)
//   probe1 [0]    pix_valid
//   probe2 [0]    pix_fsync  -- перший піксель кадру
//   probe3 [0]    start      -- AXI GPIO 0 ch2 від MicroBlaze -> frame_rx_axis
//   probe4 [3:0]  {led_ok, overflow, busy, btn}
//                 led_ok = led[0] (active-low): програма перевірила DMA і показала OK

module top (
    input  wire       clk_50m,
    input  wire       rst_n,
    input  wire [0:0] btn,
    output wire [1:0] led
);

    wire       aclk;
    wire       pix_clk;
    wire [7:0] pix_data;
    wire       pix_valid, pix_fsync;
    wire       dbg_start;
    wire [1:0] dbg_status;

    design_1_wrapper u_sys (
        .clk_50m     (clk_50m),
        .rst_n       (rst_n),
        .btn         (btn),
        .led         (led),
        .aclk_o      (aclk),
        .pix_clk_o   (pix_clk),
        .pix_clk     (pix_clk),
        .pix_data    (pix_data),
        .pix_valid   (pix_valid),
        .pix_fsync   (pix_fsync),
        .dbg_start   (dbg_start),
        .dbg_status  (dbg_status)
    );

    pix_pattern_gen u_src (
        .pix_clk   (pix_clk),
        .pix_data  (pix_data),
        .pix_valid (pix_valid),
        .pix_fsync (pix_fsync)
    );

`ifndef NO_ILA
    ila_0 u_ila (
        .clk    (aclk),
        .probe0 (pix_data),
        .probe1 (pix_valid),
        .probe2 (pix_fsync),
        .probe3 (dbg_start),
        .probe4 ({led[0], dbg_status[1], dbg_status[0], btn[0]})
    );
`endif

endmodule
