// tb_top.v -- системна Behavioral Simulation lesson14 (top без ILA: define NO_ILA).
// Той самий сценарій, що на платі під ILA: генератор кадрів працює з t=0,
// кнопка KEY2 натискається на 400 мкс, MicroBlaze (реальний ELF lesson12) дає start,
// frame_rx_axis бере наступний повний кадр, DMA пише 64000 байт, LED = OK.
// Перевірка: LED, усі 16000 слів axi4_full_ram = кадр генератора (номер кадру
// визначається з першого пікселя: pix(0,0,f) = 7f mod 256).
// VCD ila_probes.vcd містить ТІ САМІ 5 проб, що й ILA, -- для порівняння з платою.
`timescale 1ns / 1ps

module tb_top;
    reg        clk_50m = 0;
    always #10 clk_50m = ~clk_50m;
    reg        rst_n = 0;
    reg  [0:0] btn   = 1'b1;
    wire [1:0] led;

    top dut (.clk_50m(clk_50m), .rst_n(rst_n), .btn(btn), .led(led));

    `define RAM dut.u_sys.design_1_i.axi4_full_ram_0.inst.mem

    // ---- ті самі проби, що й у ILA (імена як у .ltx) ----
    wire       aclk      = dut.aclk;
    wire [7:0] probe0    = dut.pix_data;
    wire       probe1    = dut.pix_valid;
    wire       probe2    = dut.pix_fsync;
    wire       probe3    = dut.dbg_start;
    wire [3:0] probe4    = {led[0], dut.dbg_status[1], dut.dbg_status[0], btn[0]};

    initial begin
        $dumpfile("ila_probes.vcd");
        $dumpvars(0, aclk, probe0, probe1, probe2, probe3, probe4, led);
    end

    always @(posedge probe3) $display("[%0t] start=1", $time);
    always @(posedge probe2) if (probe4[1]) $display("[%0t] fsync при busy=1 (перший піксель захопленого кадру), pix_data=%02h", $time, probe0);
    always @(negedge probe4[1]) $display("[%0t] busy -> 0", $time);
    always @(led) $display("[%0t] LED = %b", $time, led);

    integer errors = 0, w, b, p, f;
    reg [31:0] got, exp;
    time t0;

    initial begin
        #1000 rst_n = 1;
        #(400_000 - 1000);
        $display("[%0t] кнопка натиснута", $time);
        btn = 0;
        t0 = $time;
        while (probe4[1] !== 1'b1 && $time - t0 < 1_000_000) #1000;
        #20_000 btn = 1;
        $display("[%0t] кнопка відпущена", $time);

        t0 = $time;
        while (led === 2'b11 && $time - t0 < 5_000_000) #1000;
        if (led !== 2'b10) begin $display("FAIL: LED = %b", led); errors = errors + 1; end
        else $display("ok:   LED = 10 (програма: DMA OK, 64000 байт, без overflow)");

        got = `RAM[0];
        f = (got[7:0] * 183) & 8'hFF;            // 7^-1 mod 256 = 183
        $display("ok?:  у RAM кадр %0d (перший піксель %02h)", f, got[7:0]);
        for (w = 0; w < 16000; w = w + 1) begin
            for (b = 0; b < 4; b = b + 1) begin
                p = w*4 + b;
                exp[8*b +: 8] = ((p % 320) + 2*(p / 320) + 7*f) & 8'hFF;
            end
            if (`RAM[w] !== exp) begin
                if (errors < 10) $display("FAIL: RAM[%0d] = %h, очікувалось %h", w, `RAM[w], exp);
                errors = errors + 1;
            end
        end
        $display("      перевірено 16000 слів RAM");
        #100_000;
        if (errors == 0) $display("SYSTEM TEST PASSED"); else $display("SYSTEM TEST FAILED: %0d", errors);
        $finish;
    end
    initial begin #8_000_000 $display("TIMEOUT"); $finish; end
endmodule
