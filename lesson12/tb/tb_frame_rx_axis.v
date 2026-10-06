// tb_frame_rx_axis.v
// Модульний self-checking testbench для frame_rx_axis (без MicroBlaze/DMA).
//
// Перевіряє:
//  T1  до start -- на M_AXIS не виходить жодного слова, хоча кадри йдуть;
//  T2  start посеред кадру -> приймається НАСТУПНИЙ повний кадр
//      (від fsync), рівно 16000 слів, TLAST лише на останньому,
//      дані побайтово збігаються з моделлю джерела; TREADY випадковий
//      (backpressure як у реального DMA);
//  T3  після кадру приймач знову ігнорує вхід (одиничний кадр на start);
//  T4  FIFO-overflow: TREADY=0 довго -> status[1]=1.
//
// Запуск: cd tb && ./run_unit.sh

`timescale 1ns / 1ps

module tb_frame_rx_axis;

    reg        pix_clk = 0;
    reg  [7:0] pix_data;
    reg        pix_valid, pix_fsync;
    reg        src_enable = 0;

    `include "pix_source.vh"

    reg aclk = 0;
    always #5 aclk = ~aclk;             // 100 МГц
    reg aresetn = 0;

    reg         start = 0;
    wire [1:0]  status;
    wire [31:0] m_axis_tdata;
    wire [3:0]  m_axis_tkeep;
    wire        m_axis_tlast, m_axis_tvalid;
    reg         m_axis_tready = 0;

    frame_rx_axis #(.FRAME_W(FRAME_W), .FRAME_H(FRAME_H)) dut (
        .pix_clk(pix_clk), .pix_data(pix_data), .pix_valid(pix_valid), .pix_fsync(pix_fsync),
        .aclk(aclk), .aresetn(aresetn),
        .start(start), .status(status),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep), .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready)
    );

    // ---------------- випадковий TREADY ----------------
    reg rand_ready = 1;
    reg force_low  = 0;
    always @(posedge aclk)
        m_axis_tready <= !force_low && (rand_ready ? ($random % 10 < 7) : 1'b1);

    // ---------------- scoreboard ----------------
    integer errors     = 0;
    integer words      = 0;        // слів у поточній транзакції
    integer total      = 0;        // слів за весь час
    integer lasts      = 0;
    integer got_frame  = -1;
    integer checking   = 1;

    always @(posedge aclk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            total = total + 1;
            if (checking) begin
                if (words == 0) begin : find_frame
                    integer f;
                    got_frame = -1;
                    for (f = 0; f < 64; f = f + 1)
                        if (got_frame < 0 && m_axis_tdata[7:0] == pix_value(0, 0, f))
                            got_frame = f;
                end
                if (m_axis_tdata !== word_value(words, got_frame)) begin
                    if (errors < 10)
                        $display("[%0t] DATA ERR word %0d: got %h exp %h", $time, words,
                                 m_axis_tdata, word_value(words, got_frame));
                    errors = errors + 1;
                end
                if (m_axis_tlast !== (words == FRAME_WORDS-1)) begin
                    $display("[%0t] TLAST ERR word %0d tlast=%b", $time, words, m_axis_tlast);
                    errors = errors + 1;
                end
                if (m_axis_tkeep !== 4'hF) errors = errors + 1;
            end
            words = words + 1;
            if (m_axis_tlast) begin
                lasts = lasts + 1;
                $display("[%0t] TLAST: %0d words, frame #%0d", $time, words, got_frame);
                words = 0;
            end
        end
    end

    // перший кадр, що почався після фронту start (+ запас на синхронізатор)
    function integer expected_frame(input time t_start);
        integer f;
        begin
            expected_frame = -1;
            for (f = 63; f >= 0; f = f - 1)
                if (f <= src_frame && sof_time[f] > t_start + 100) expected_frame = f;
        end
    endfunction

    time t_start;
    integer exp_f;

    task check(input cond, input [8*64-1:0] msg);
        if (!cond) begin
            $display("FAIL: %0s", msg);
            errors = errors + 1;
        end else
            $display("ok:   %0s", msg);
    endtask

    initial begin
        src_enable = 1;                       // джерело працює з самого початку
        #200 aresetn = 1;

        // ---- T1: кадр 0 проходить, start=0 ----
        #(2_200_000);                         // > 1 кадру (1.85 мс)
        check(total == 0, "T1 no output before start");

        // ---- T2: start посеред кадру 1 ----
        @(posedge aclk) start = 1; t_start = $time;
        $display("[%0t] start=1 (src frame %0d in progress)", $time, src_frame);
        #(1000) check(status[0] == 1, "T2 busy after start");
        wait (lasts == 1);
        exp_f = expected_frame(t_start);
        @(posedge aclk) start = 0;
        check(got_frame == exp_f, "T2 captured first full frame after start");
        check(total == FRAME_WORDS, "T2 exactly 16000 words");
        check(errors == 0, "T2 data + TLAST match");
        #(1000) check(status == 2'b00, "T2 idle, no overflow");

        // ---- T3: наступний кадр має бути проігнорований ----
        #(2_000_000);
        check(total == FRAME_WORDS, "T3 no output after frame done");

        // ---- T4: overflow ----
        checking  = 0;
        force_low = 1;
        @(posedge aclk) start = 1;
        #(2_000_000);
        check(status[1] == 1, "T4 overflow flagged when sink stalls");
        force_low = 0;
        @(posedge aclk) start = 0;
        #(2_000_000);

        $display("==================================================");
        if (errors == 0) $display("UNIT TEST PASSED");
        else             $display("UNIT TEST FAILED: %0d errors", errors);
        $display("==================================================");
        $finish;
    end

endmodule
