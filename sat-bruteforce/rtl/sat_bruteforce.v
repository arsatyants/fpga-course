// Параллельный перебор 3-SAT (любой k-SAT/CNF).
//
// Формула хранится как две маски на клаузу: pos[i]=1 -> литерал x_i, neg[i]=1 -> литерал ~x_i.
// Клауза выполнена назначением a, если |((a & pos) | (~a & neg)).
// Маски — константы ($readmemh, без порта записи), поэтому синтез сворачивает
// каждую 3-литеральную клаузу в один LUT3, а всю формулу — в дерево AND.
//
// P = 2^LOGP ядер. Ядро k на такте с счётчиком cnt проверяет назначение a = cnt*P + k.
// За такт проверяется P назначений, весь перебор — 2^(N-LOGP) тактов.
// Порядок обхода совпадает с возрастанием a, поэтому найденное решение —
// минимальное выполняющее назначение (удобно для эталона в тестбенче).
//
// Конвейер: cnt -> [stage1: оценка P формул] -> [stage2: приоритетный шифратор].
module sat_bruteforce #(
    parameter N       = 32,              // число переменных
    parameter M       = 137,             // число клауз
    parameter LOGP    = 5,               // log2(число параллельных ядер), 0 <= LOGP < N
    parameter MEMFILE = "formula.mem"    // M строк hex: {neg[N-1:0], pos[N-1:0]}
)(
    input  wire           clk,
    input  wire           rst,
    input  wire           start,         // импульс: начать перебор с нуля
    output reg            busy,
    output reg            done,          // перебор закончен (решение найдено или пространство исчерпано)
    output reg            found,         // 1 = SAT, 0 = UNSAT (валидно при done)
    output reg  [N-1:0]   solution,
    output reg  [47:0]    cycles         // тактов от start до done
);
    localparam P = 1 << LOGP;
    localparam W = N - LOGP;             // разрядность счётчика

    reg [2*N-1:0] rom [0:M-1];
    initial $readmemh(MEMFILE, rom);

    // ---- stage 0: счётчик ----
    reg  [W-1:0] cnt;
    reg          run;
    wire         cnt_last = &cnt;
    wire [N-1:0] cnt_n    = cnt;     // нулевое расширение до N бит

    // ---- stage 1: P копий формулы ----
    wire [P-1:0] sat_now;
    genvar k, j;
    generate
        for (k = 0; k < P; k = k + 1) begin : core
            wire [N-1:0] a = (cnt_n << LOGP) | k;
            wire [M-1:0] ok;
            for (j = 0; j < M; j = j + 1) begin : clause
                assign ok[j] = |((a & rom[j][N-1:0]) | (~a & rom[j][2*N-1:N]));
            end
            assign sat_now[k] = &ok;
        end
    endgenerate

    reg  [P-1:0] sat_q;
    reg  [W-1:0] cnt_q;
    wire [N-1:0] cnt_q_n = cnt_q;
    reg          valid_q, last_q;

    // ---- stage 2: первый (младший) выполняющий k ----
    reg  [LOGP:0] first_k;               // +1 бит, чтобы при LOGP=0 ширина не была нулевой
    integer i;
    always @* begin
        first_k = 0;
        for (i = P - 1; i >= 0; i = i - 1)
            if (sat_q[i]) first_k = i;
    end

    always @(posedge clk) begin
        if (rst) begin
            busy <= 0; done <= 0; found <= 0; run <= 0;
            valid_q <= 0; last_q <= 0; cnt <= 0;
            solution <= 0; cycles <= 0;
        end else begin
            // stage 0
            if (start && !busy) begin
                busy <= 1; done <= 0; found <= 0; run <= 1;
                cnt <= 0; cycles <= 0; solution <= 0;
            end else if (run) begin
                cnt <= cnt + 1'b1;
                if (cnt_last) run <= 0;
            end
            if (busy) cycles <= cycles + 1'b1;

            // stage 1
            sat_q   <= sat_now;
            cnt_q   <= cnt;
            valid_q <= run;
            last_q  <= run && cnt_last;

            // stage 2
            if (busy && valid_q) begin
                if (|sat_q) begin
                    found    <= 1;
                    solution <= (cnt_q_n << LOGP) | first_k;
                    done <= 1; busy <= 0; run <= 0; valid_q <= 0; last_q <= 0;
                end else if (last_q) begin
                    done <= 1; busy <= 0;
                end
            end
        end
    end
endmodule
