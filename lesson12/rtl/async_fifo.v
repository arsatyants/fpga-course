// async_fifo.v
// Асинхронний FIFO (два незалежні такти) з Gray-кодованими вказівниками
// за класичною схемою C. Cummings ("Simulation and Synthesis Techniques
// for Asynchronous FIFO Design", SNUG 2002).
//
//  * запис  -- у домені wr_clk, читання -- у домені rd_clk;
//  * вказівники мають ADDR_W+1 біт (старший біт розрізняє full/empty);
//  * через межу доменів передаються ЛИШЕ Gray-коди вказівників
//    (за один такт змінюється рівно один біт) через 2 тригери-синхронізатори;
//  * читання -- First-Word-Fall-Through: rd_data валідне, поки !rd_empty,
//    тому вихід FIFO напряму стає AXI4-Stream (tvalid = !empty, pop = tvalid&tready).

module async_fifo #(
    parameter DATA_W = 33,
    parameter ADDR_W = 4            // глибина = 2**ADDR_W слів
) (
    // ---- домен запису ----
    input  wire              wr_clk,
    input  wire              wr_rst_n,     // синхронно знятий у домені wr_clk
    input  wire              wr_en,
    input  wire [DATA_W-1:0] wr_data,
    output reg               wr_full,

    // ---- домен читання ----
    input  wire              rd_clk,
    input  wire              rd_rst_n,     // синхронно знятий у домені rd_clk
    input  wire              rd_en,
    output wire [DATA_W-1:0] rd_data,
    output reg               rd_empty
);

    localparam DEPTH = 1 << ADDR_W;

    reg [DATA_W-1:0] mem [0:DEPTH-1];

    // ------------------------------------------------------------------
    // Домен запису
    // ------------------------------------------------------------------
    reg  [ADDR_W:0] wbin, wgray;
    reg  [ADDR_W:0] rbin, rgray;     // (оголошено тут, бо rgray синхронізується в домен запису)
    (* ASYNC_REG = "TRUE" *) reg [ADDR_W:0] rgray_w1, rgray_w2;

    wire            wr_do      = wr_en && !wr_full;
    wire [ADDR_W:0] wbin_next  = wbin + {{ADDR_W{1'b0}}, wr_do};
    wire [ADDR_W:0] wgray_next = (wbin_next >> 1) ^ wbin_next;

    always @(posedge wr_clk) begin
        if (wr_do)
            mem[wbin[ADDR_W-1:0]] <= wr_data;
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wbin     <= 0;
            wgray    <= 0;
            rgray_w1 <= 0;
            rgray_w2 <= 0;
            wr_full  <= 1'b0;
        end else begin
            wbin     <= wbin_next;
            wgray    <= wgray_next;
            rgray_w1 <= rgray;
            rgray_w2 <= rgray_w1;
            // full: Gray-вказівник запису == Gray-вказівник читання з
            // інвертованими двома старшими бітами
            wr_full  <= (wgray_next == {~rgray_w2[ADDR_W:ADDR_W-1], rgray_w2[ADDR_W-2:0]});
        end
    end

    // ------------------------------------------------------------------
    // Домен читання
    // ------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [ADDR_W:0] wgray_r1, wgray_r2;

    wire            rd_do      = rd_en && !rd_empty;
    wire [ADDR_W:0] rbin_next  = rbin + {{ADDR_W{1'b0}}, rd_do};
    wire [ADDR_W:0] rgray_next = (rbin_next >> 1) ^ rbin_next;

    // FWFT: комбінаційне читання (для малої глибини -- distributed RAM)
    assign rd_data = mem[rbin[ADDR_W-1:0]];

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rbin     <= 0;
            rgray    <= 0;
            wgray_r1 <= 0;
            wgray_r2 <= 0;
            rd_empty <= 1'b1;
        end else begin
            rbin     <= rbin_next;
            rgray    <= rgray_next;
            wgray_r1 <= wgray;
            wgray_r2 <= wgray_r1;
            rd_empty <= (rgray_next == wgray_r2);
        end
    end

endmodule
