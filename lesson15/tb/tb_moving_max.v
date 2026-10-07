`timescale 1ns/1ps
// tb_moving_max.v -- lesson 15
// Тестбенч для HLS IP moving_max (версія з PIPELINE II=1) у звичайному Verilog-проєкті Vivado:
// без Block Design і без процесора. Дві моделі RAM (in_data, out_data) за інтерфейсом ap_memory,
// керування ap_ctrl_hs. Ті самі 7 типів векторів, що в src/moving_max_tb.cpp, еталон -- прямий перебір
// out[n] = max(in[max(0,n-7)] .. in[n]) (знакове порівняння). Для кожного виклику міряється
// латентність ap_start -> ap_done.
//
// Ім'я компонента moving_max_0 -- з vivado/create_project.tcl (create_ip ... -module_name moving_max_0).

module tb_moving_max;

    localparam N_SAMPLES = 64;
    localparam WINDOW    = 8;
    localparam N_VECTORS = 7;
    localparam RD_LAT    = 1;   // затримка читання RAM для ap_memory

    reg clk = 1'b0;
    reg rst = 1'b1;             // ap_rst активний ВИСОКИМ рівнем
    reg ap_start = 1'b0;
    wire ap_done, ap_idle, ap_ready;

    wire [5:0]  in_data_address0;
    wire        in_data_ce0;
    wire [31:0] in_data_q0;
    wire [5:0]  out_data_address0;
    wire        out_data_ce0;
    wire        out_data_we0;
    wire [31:0] out_data_d0;

    always #5 clk = ~clk;       // 100 МГц

    // ---------- DUT ----------
    moving_max_0 dut (
        .ap_clk            (clk),
        .ap_rst            (rst),
        .ap_start          (ap_start),
        .ap_done           (ap_done),
        .ap_idle           (ap_idle),
        .ap_ready          (ap_ready),
        .in_data_address0  (in_data_address0),
        .in_data_ce0       (in_data_ce0),
        .in_data_q0        (in_data_q0),
        .out_data_address0 (out_data_address0),
        .out_data_ce0      (out_data_ce0),
        .out_data_we0      (out_data_we0),
        .out_data_d0       (out_data_d0)
    );

    // ---------- Моделі зовнішніх RAM ----------
    reg signed [31:0] mem_in  [0:N_SAMPLES-1];
    reg signed [31:0] mem_out [0:N_SAMPLES-1];
    reg [31:0] q_a, q_b;
    // Перевірка "кожен in читається один раз": перші N_SAMPLES звернень (in_data_ce0=1) мають іти
    // по адресах 0..63 рівно по разу. Конвеєр II=1 на виході з циклу робить ще одне СПЕКУЛЯТИВНЕ
    // читання (ce0 стадії 0 не залежить від умови виходу n==64; адреса 64 -> 6 біт = 0), результат
    // якого відкидається -- його рахуємо окремо і не вважаємо помилкою.
    integer rd_count;           // скільки тактів з in_data_ce0=1 за виклик
    integer rd_order_err;       // звернення i (< N_SAMPLES) пішло не на адресу i

    always @(posedge clk) begin
        if (in_data_ce0) begin
            q_a <= mem_in[in_data_address0];
            if (rd_count < N_SAMPLES && in_data_address0 != rd_count) rd_order_err <= rd_order_err + 1;
            rd_count <= rd_count + 1;
        end
        q_b <= q_a;
        if (out_data_ce0 && out_data_we0) mem_out[out_data_address0] <= out_data_d0;
    end
    assign in_data_q0 = (RD_LAT == 1) ? q_a : q_b;

    // Для waveform: поточний вхідний відлік / записаний результат як знакові числа
    wire signed [31:0] in_sample  = in_data_q0;
    wire signed [31:0] out_sample = out_data_d0;

    // ---------- Вхідні вектори (як make_vector у moving_max_tb.cpp) ----------
    reg [31:0] seed;
    function [31:0] rnd;        // seed = seed*1103515245 + 12345; return seed >> 1
        input dummy;
        begin
            seed = seed * 32'd1103515245 + 32'd12345;
            rnd  = seed >> 1;
        end
    endfunction

    task make_vector;
        input integer v;
        integer n;
        reg [31:0] a, b;
        begin
            for (n = 0; n < N_SAMPLES; n = n + 1) begin
                case (v)
                    0: mem_in[n] = rnd(0) % 1000;
                    1: begin a = rnd(0); b = rnd(0); mem_in[n] = (a << 1) ^ b; end
                    2: mem_in[n] = 3 * n - 50;
                    3: mem_in[n] = 1000 - 7 * n;
                    4: mem_in[n] = -5;
                    5: mem_in[n] = (n & 1) ? 32'h7FFF_FFFF : 32'h8000_0000;
                    default: mem_in[n] = (n % 11 == 3) ? 100 + n : -1000 - n;
                endcase
                mem_out[n] = 32'hDEADBEEF;  // маркер: якщо блок не запише, побачимо
            end
            if (v == 6) mem_in[0] = 32'h8000_0000;
        end
    endtask

    // ---------- Еталон: прямий перебір ----------
    reg signed [31:0] golden [0:N_SAMPLES-1];

    task make_golden;
        integer n, i, lo;
        reg signed [31:0] m;
        begin
            for (n = 0; n < N_SAMPLES; n = n + 1) begin
                lo = (n - (WINDOW - 1) < 0) ? 0 : n - (WINDOW - 1);
                m  = mem_in[lo];
                for (i = lo + 1; i <= n; i = i + 1)
                    if (mem_in[i] > m) m = mem_in[i];
                golden[n] = m;
            end
        end
    endtask

    // ---------- Один виклик блока за протоколом ap_ctrl_hs ----------
    integer errors, latency;
    time    t_start;            // момент ap_start=1 поточного виклику
    integer vec;                // номер вектора -- видно у waveform

    task run_once;
        integer cnt;
        begin
            rd_count = 0;
            rd_order_err = 0;
            @(negedge clk);
            ap_start = 1'b1;
            t_start  = $time;
            cnt = 0;
            @(negedge clk);
            while (!ap_done && cnt < 5000) begin
                @(negedge clk);
                cnt = cnt + 1;
            end
            latency = cnt + 1;      // такти від фронту зі start=1 до фронту з done=1
            if (!ap_done) begin
                $display("TIMEOUT: ap_done never came");
                errors = errors + 1;
            end
            ap_start = 1'b0;        // ap_done/ap_ready побачено: знімаємо ap_start
            cnt = 0;
            while (!ap_idle && cnt < 100) begin
                @(negedge clk);
                cnt = cnt + 1;
            end
        end
    endtask

    // ---------- Основний сценарій ----------
    integer n, bad;

    initial begin
        errors = 0;
        seed   = 32'd12345;
        vec    = -1;
        rd_count = 0;
        rd_order_err = 0;

        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        for (vec = 0; vec < N_VECTORS; vec = vec + 1) begin
            make_vector(vec);
            make_golden;
            run_once;
            repeat (3) @(negedge clk);
            bad = 0;
            for (n = 0; n < N_SAMPLES; n = n + 1) begin
                if (mem_out[n] !== golden[n]) begin
                    bad = bad + 1;
                    if (bad <= 5)
                        $display("MISMATCH: vector %0d, sample %0d: in=%0d DUT=%0d, ref=%0d",
                                 vec, n, mem_in[n], mem_out[n], golden[n]);
                end
            end
            if (rd_count < N_SAMPLES || rd_order_err != 0) begin
                $display("vector %0d: in_data reads %0d, out of order %0d", vec, rd_count, rd_order_err);
                bad = bad + 1;
            end
            $display("vector %0d: %s, latency %0d cycles, in_data reads %0d + %0d speculative, start %0d ns",
                     vec, bad ? "FAIL" : "ok", latency, N_SAMPLES, rd_count - N_SAMPLES, t_start);
            errors = errors + bad;
        end

        if (errors == 0) $display("Test passed !");
        else             $display("Test FAILED: %0d errors", errors);
        $finish;
    end

    // Захист від зависання
    initial begin
        #500000;
        $display("TIMEOUT: simulation too long");
        $finish;
    end

endmodule
