`timescale 1ns/1ps

module tb_linear_relu_int4;
    localparam N = 4;
    logic clk, rst_n, start, done;
    logic signed [N-1:0][31:0] y_out;
    integer i, fd, cycles;
    string out_hex, out_cyc;

    linear_relu_int4 #(.N(N)) dut (
        .clk, .rst_n, .start, .done, .y_out
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        out_hex = "tests/golden/int4_4x4/rtl_output.hex";
        out_cyc = "tests/golden/int4_4x4/rtl_cycles.txt";
        void'($value$plusargs("out_hex=%s", out_hex));
        void'($value$plusargs("out_cyc=%s", out_cyc));
        rst_n = 0; start = 0; cycles = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        while (!done) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles > 200) begin
                $display("TIMEOUT int4");
                $finish;
            end
        end
        fd = $fopen(out_hex, "w");
        for (i = 0; i < N; i = i + 1) begin
            $fdisplay(fd, "%08h", y_out[i]);
            $display("int4 y[%0d]=%0d", i, y_out[i]);
        end
        $fclose(fd);
        fd = $fopen(out_cyc, "w");
        $fdisplay(fd, "%0d", cycles);
        $fclose(fd);
        $finish;
    end
endmodule
