// Юнит-тест sat_bruteforce: результат против эталона gen_cnf.py --ref,
// независимая проверка решения по маскам, число тактов, повторный запуск.
// LOGP задаётся через -DLOGP_TB=..., формула — formula_params.vh / formula.mem в cwd.
`timescale 1ns/1ps
module tb_sat_bruteforce;
    `include "formula_params.vh"
`ifndef LOGP_TB
    `define LOGP_TB 2
`endif
    localparam LOGP = `LOGP_TB;

    reg clk = 0, rst = 1, start = 0;
    always #10 clk = ~clk;

    wire busy, done, found;
    wire [N-1:0] solution;
    wire [47:0]  cycles;

    sat_bruteforce #(.N(N), .M(M), .LOGP(LOGP), .MEMFILE("formula.mem")) dut (
        .clk(clk), .rst(rst), .start(start),
        .busy(busy), .done(done), .found(found), .solution(solution), .cycles(cycles)
    );

    reg [2*N-1:0] f [0:M-1];
    integer errors = 0, run, j;
    reg ok_all;
    reg [47:0] max_cyc, first_cyc;

    initial begin
        $readmemh("formula.mem", f);
        max_cyc = (48'd1 << (N - LOGP)) + 4;
        repeat (3) @(posedge clk);
        rst <= 0;
        for (run = 0; run < 2; run = run + 1) begin
            @(posedge clk); start <= 1;
            @(posedge clk); start <= 0;
            wait (!done); wait (done);
            @(posedge clk);
            $display("LOGP=%0d run %0d: found=%0d sol=0x%h cycles=%0d (ref found=%0d sol=0x%h)",
                     LOGP, run, found, solution, cycles, REF_FOUND, REF_SOL);
            if (found !== REF_FOUND[0])                  begin $display("FAIL found"); errors = errors + 1; end
            if (found && solution !== REF_SOL)           begin $display("FAIL solution"); errors = errors + 1; end
            if (found) begin
                ok_all = 1;
                for (j = 0; j < M; j = j + 1)
                    ok_all = ok_all & |((solution & f[j][N-1:0]) | (~solution & f[j][2*N-1:N]));
                if (!ok_all)                             begin $display("FAIL solution does not satisfy"); errors = errors + 1; end
                // решение a находится на такте ~a/P от старта
                if (cycles > (solution >> LOGP) + 4)     begin $display("FAIL too many cycles"); errors = errors + 1; end
            end else if (cycles > max_cyc || cycles < max_cyc - 4) begin
                $display("FAIL unsat cycles, expected ~%0d", max_cyc); errors = errors + 1;
            end
            if (run == 0) first_cyc = cycles;
            else if (cycles !== first_cyc)               begin $display("FAIL rerun differs"); errors = errors + 1; end
        end
        if (errors == 0) $display("PASS");
        else             $display("FAILED: %0d errors", errors);
        $finish;
    end

    initial begin
        #200_000_000 $display("FAIL timeout"); $finish;
    end
endmodule
