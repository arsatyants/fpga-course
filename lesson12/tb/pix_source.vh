// pix_source.vh
// Спільна для обох testbench модель зовнішнього джерела кадрів
// (підключається `include всередині модуля testbench).
//
// Формат (власне рішення):
//   * pix_clk = 40 МГц (період 25 нс), асинхронний до системних 100 МГц;
//   * кадр 320x200, 1 байт/такт, рядок = 320 тактів pix_valid=1 + H_BLANK тактів 0;
//   * між кадрами V_BLANK тактів pix_valid=0;
//   * pix_fsync=1 разом із першим пікселем кадру;
//   * значення пікселя: pix_value(x, y, f) = (x + 2*y + 7*f) & 8'hFF,
//     де f -- порядковий номер кадру від початку симуляції.
//     Номер кадру закодовано у даних -> testbench знає, ЯКИЙ кадр потрапив у пам'ять.
//   * дані змінюються по СПАДУ pix_clk, приймач захоплює по ФРОНТУ.
//
// Потрібні в модулі, що включає файл:
//   reg pix_clk; reg [7:0] pix_data; reg pix_valid, pix_fsync; reg src_enable;

localparam integer FRAME_W   = 320;
localparam integer FRAME_H   = 200;
localparam integer H_BLANK   = 40;
localparam integer V_BLANK   = 2000;
localparam integer FRAME_PIX = FRAME_W * FRAME_H;      // 64000 байт
localparam integer FRAME_WORDS = FRAME_PIX / 4;        // 16000 слів

function [7:0] pix_value(input integer x, input integer y, input integer f);
    pix_value = (x + 2*y + 7*f) & 8'hFF;
endfunction

function [31:0] word_value(input integer widx, input integer f);
    integer b, p;
    begin
        for (b = 0; b < 4; b = b + 1) begin
            p = widx*4 + b;
            word_value[8*b +: 8] = pix_value(p % FRAME_W, p / FRAME_W, f);
        end
    end
endfunction

integer src_frame = 0;               // номер кадру, що зараз передається
time    sof_time [0:63];             // момент початку кожного кадру

always #12.5 pix_clk = ~pix_clk;     // 40 МГц

initial begin : pix_gen
    integer x, y;
    pix_data  = 8'h00;
    pix_valid = 1'b0;
    pix_fsync = 1'b0;
    wait (src_enable);
    forever begin
        for (y = 0; y < FRAME_H; y = y + 1) begin
            for (x = 0; x < FRAME_W; x = x + 1) begin
                @(negedge pix_clk);
                pix_valid = 1'b1;
                pix_fsync = (x == 0 && y == 0);
                pix_data  = pix_value(x, y, src_frame);
                if (x == 0 && y == 0) sof_time[src_frame % 64] = $time;
            end
            repeat (H_BLANK) begin
                @(negedge pix_clk);
                pix_valid = 1'b0;
                pix_fsync = 1'b0;
                pix_data  = $random;     // сміття в бланкінгу -- має ігноруватись
            end
        end
        repeat (V_BLANK) begin
            @(negedge pix_clk);
            pix_valid = 1'b0;
            pix_fsync = 1'b0;
            pix_data  = $random;
        end
        src_frame = src_frame + 1;
    end
end
