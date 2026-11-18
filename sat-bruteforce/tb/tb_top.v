// Тест top: автозапуск после сброса, приём строки с UART, сравнение с ожидаемой.
`timescale 1ns/1ps
module tb_top;
    `include "formula_params.vh"
    localparam CPB  = 8;                 // ускоренный UART для симуляции
    localparam HEXN = (N + 3) / 4;
    localparam L    = 6 + 2 + HEXN + 5 + 12 + 2;

    reg clk = 0, rst_n = 0;
    reg [0:0] btn = 1;
    always #10 clk = ~clk;
    wire [1:0] led;
    wire tx;

    top #(.LOGP(2), .CLKS_PER_BIT(CPB), .MEMFILE("formula.mem")) dut (
        .clk_50m(clk), .rst_n(rst_n), .btn(btn), .led(led), .uart_tx(tx)
    );

    // ---- приёмник UART ----
    reg [8*L-1:0] line = 0, line_lc = 0;   // как принято / в нижнем регистре
    integer nrx = 0, b;
    reg [7:0] c;
    always begin
        @(negedge tx);
        repeat (CPB / 2) @(posedge clk);
        for (b = 0; b < 8; b = b + 1) begin
            repeat (CPB) @(posedge clk);
            c[b] = tx;
        end
        repeat (CPB) @(posedge clk);
        line = {line[8*L-9:0], c};
        if (c >= "A" && c <= "Z") c = c + 8'd32;  // $sformat %h печатает строчные
        line_lc = {line_lc[8*L-9:0], c};
        nrx  = nrx + 1;
    end

    reg [8*L-1:0] exp_line;
    reg [4*HEXN-1:0] sol_pad;
    initial begin
        repeat (5) @(posedge clk);
        rst_n <= 1;
        wait (nrx == L);
        sol_pad = dut.u_sat.solution;
        $sformat(exp_line, "%s x=%h cyc=%h\015\n",
                 dut.u_sat.found ? "sat  " : "unsat", sol_pad, dut.u_sat.cycles);
        $write("uart: %s", line);
        $display("led=%b", led);
        if (line_lc === exp_line && led[1] && led[0] === dut.u_sat.found) $display("PASS");
        else begin $write("FAIL, expected: %s", exp_line); end
        $finish;
    end

    initial begin
        #200_000_000 $display("FAIL timeout"); $finish;
    end
endmodule
