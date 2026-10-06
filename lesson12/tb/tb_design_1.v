// tb_design_1.v
// Системний self-checking testbench (Behavioral Simulation) для design_1_wrapper:
// MicroBlaze (виконує реальний frame_dma_mb.elf з LMB BRAM) + AXI GPIO + frame_rx_axis
// + AXI DMA (S2MM) + axi4_full_ram.
//
// Сценарій:
//  1. Зовнішнє джерело (pix_source.vh) шле кадри 320x200 @ 40 МГц З САМОГО ПОЧАТКУ,
//     ще до reset і до натискання кнопки -> жодне слово не має потрапити в DMA.
//  2. На 400 мкс "натискається" кнопка (btn=0, active-low) і утримується, поки
//     приймач не стане busy (як людина, що тримає кнопку довше за опитування CPU).
//  3. MicroBlaze: налаштовує DMA S2MM на 64000 байт, дає start=1.
//     frame_rx_axis чекає наступного fsync і передає рівно один кадр.
//  4. Програма перевіряє статус DMA/довжину/overflow і запалює led[0] (OK, active-low).
//  5. TB чекає led == 2'b10, перевіряє ВСІ 16000 слів axi4_full_ram проти моделі
//     джерела (очікуваний кадр -- перший, що почався після фронту start),
//     і що після кадру в DMA більше нічого не йде.

`timescale 1ns / 1ps

module tb_design_1;

    // ---------------- зовнішнє джерело кадрів ----------------
    reg        pix_clk = 0;
    reg  [7:0] pix_data;
    reg        pix_valid, pix_fsync;
    reg        src_enable = 0;

    `include "pix_source.vh"

    // ---------------- система ----------------
    reg        clk_50m = 0;
    always #10 clk_50m = ~clk_50m;      // 50 МГц, як на платі (N18)
    reg        rst_n = 0;
    reg  [0:0] btn   = 1'b1;            // відпущена (active-low)
    wire [1:0] led;

    design_1_wrapper dut (
        .clk_50m   (clk_50m),
        .rst_n     (rst_n),
        .btn       (btn),
        .led       (led),
        .pix_clk   (pix_clk),
        .pix_data  (pix_data),
        .pix_valid (pix_valid),
        .pix_fsync (pix_fsync)
    );

    // ---------------- зонди всередині BD ----------------
    `define RX   dut.design_1_i.frame_rx_0.inst
    `define RAM  dut.design_1_i.axi4_full_ram_0.inst.mem

    integer stream_words = 0;
    integer stream_lasts = 0;
    always @(posedge `RX.aclk)
        if (`RX.m_axis_tvalid && `RX.m_axis_tready) begin
            stream_words = stream_words + 1;
            if (`RX.m_axis_tlast) stream_lasts = stream_lasts + 1;
            if (stream_words % 4000 == 0)
                $display("[%0t] DMA прийняв %0d слів", $time, stream_words);
        end

    time t_start = 0;
    always @(posedge `RX.start) begin
        t_start = $time;
        $display("[%0t] MicroBlaze: start=1 (джерело передає кадр %0d)", $time, src_frame);
    end

    always @(led)
        $display("[%0t] LED = %b", $time, led);

    always @(src_frame)
        $display("[%0t] джерело: кадр %0d", $time, src_frame);

    function integer expected_frame(input time ts);
        integer f;
        begin
            expected_frame = -1;
            for (f = 63; f >= 0; f = f - 1)
                if (f <= src_frame && sof_time[f] > ts + 100) expected_frame = f;
        end
    endfunction

    // ---------------- сценарій ----------------
    integer errors = 0;
    integer w, exp_f;
    reg [31:0] got;
    time t_wait;

    initial begin
        src_enable = 1;                   // кадри йдуть одразу
        rst_n = 0;
        #1000;
        rst_n = 1;
        $display("[%0t] reset знято", $time);

        // ---- до кнопки: вхід ігнорується ----
        #(400_000 - 1000);
        if (stream_words != 0) begin
            $display("FAIL: %0d слів пройшло в DMA ДО натискання кнопки", stream_words);
            errors = errors + 1;
        end else
            $display("ok:   до кнопки в DMA не пройшло жодного слова (кадр %0d ігнорується)", src_frame);

        // ---- натискання кнопки ----
        $display("[%0t] кнопка натиснута", $time);
        btn = 1'b0;
        t_wait = $time;
        while (`RX.status[0] !== 1'b1 && $time - t_wait < 1_000_000) #1000;
        #(20_000);
        btn = 1'b1;
        $display("[%0t] кнопка відпущена", $time);
        if (t_start == 0) begin
            $display("FAIL: MicroBlaze не дав start");
            errors = errors + 1;
        end

        // ---- чекаємо результат програми ----
        t_wait = $time;
        while (led === 2'b11 && $time - t_wait < 5_000_000) #1000;

        if (led !== 2'b10) begin
            $display("FAIL: LED = %b (очікувалось 10: led[0]=OK)", led);
            errors = errors + 1;
        end else
            $display("ok:   програма MicroBlaze повідомила OK (DMA без помилок, 64000 байт, без overflow)");

        if (stream_words != FRAME_WORDS || stream_lasts != 1) begin
            $display("FAIL: в DMA пройшло %0d слів / %0d TLAST (очікувалось %0d / 1)",
                     stream_words, stream_lasts, FRAME_WORDS);
            errors = errors + 1;
        end else
            $display("ok:   в DMA пройшло рівно %0d слів, один TLAST", FRAME_WORDS);

        // ---- вміст axi4_full_ram ----
        exp_f = expected_frame(t_start);
        $display("[%0t] перевірка axi4_full_ram: очікується кадр %0d", $time, exp_f);
        for (w = 0; w < FRAME_WORDS; w = w + 1) begin
            got = `RAM[w];
            if (got !== word_value(w, exp_f)) begin
                if (errors < 10)
                    $display("FAIL: RAM[%0d] = %h, очікувалось %h", w, got, word_value(w, exp_f));
                errors = errors + 1;
            end
        end
        $display("[%0t] RAM: перевірено %0d слів", $time, FRAME_WORDS);

        // ---- після кадру приймач знову ігнорує вхід ----
        #(500_000);
        if (stream_words != FRAME_WORDS) begin
            $display("FAIL: після кадру пройшло ще %0d слів", stream_words - FRAME_WORDS);
            errors = errors + 1;
        end else
            $display("ok:   після кадру вхід знову ігнорується");

        $display("==================================================");
        if (errors == 0) $display("SYSTEM TEST PASSED");
        else             $display("SYSTEM TEST FAILED: %0d errors", errors);
        $display("==================================================");
        $finish;
    end

    initial begin
        #(10_000_000);
        $display("TIMEOUT");
        $finish;
    end

endmodule
