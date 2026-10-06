`timescale 1ns/1ps

module tb_gemv;
    parameter N = 4;
    logic clk, rst_n, start, done;
    logic signed [N-1:0][31:0] y_out;
    integer i, fd, cycles;
    string out_hex, out_cyc;

    gemv #(.N(N), .DATA_WIDTH(8)) dut (
        .clk, .rst_n, .start, .done, .y_out
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        out_hex = "results/rtl_output.hex";
        out_cyc = "results/rtl_cycles.txt";
        void'($value$plusargs("out_hex=%s", out_hex));
        void'($value$plusargs("out_cyc=%s", out_cyc));
        rst_n = 1'b0; start = 1'b0; cycles = 0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        while (!done) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles > (20 * N + 200)) begin
                $display("TIMEOUT gemv N=%0d", N);
                $finish;
            end
        end
        fd = $fopen(out_hex, "w");
        for (i = 0; i < N; i = i + 1)
            $fdisplay(fd, "%08h", y_out[i]);
        $fclose(fd);
        fd = $fopen(out_cyc, "w");
        $fdisplay(fd, "%0d", cycles);
        $fclose(fd);
        $finish;
    end
endmodule
