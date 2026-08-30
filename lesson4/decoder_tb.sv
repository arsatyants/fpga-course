`timescale 1ns / 1ps

module decoder_tb;

    localparam WIDTH = 4;

    logic                  en;
    logic [WIDTH-1:0]      sel;
    logic [(1<<WIDTH)-1:0] out;

    decoder #(.WIDTH(WIDTH)) dut (
        .en  (en),
        .sel (sel),
        .out (out)
    );

    initial begin
        en = 0;
        sel = '0;
        #10;

        en = 1;
        for (int i = 0; i < (1<<WIDTH); i++) begin
            sel = i[WIDTH-1:0];
            #10;
            if (out !== (1 << sel))
                $error("Mismatch: sel=%0d out=%b", sel, out);
        end

        en = 0;
        sel = 0;
        #10;
        if (out !== '0)
            $error("Mismatch: en=0 should give out=0, got %b", out);

        $display("decoder_tb: all checks passed");
        $finish;
    end

endmodule
