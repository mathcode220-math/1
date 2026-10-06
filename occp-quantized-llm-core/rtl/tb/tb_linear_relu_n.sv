`timescale 1ns/1ps

module tb_linear_relu_n;

    parameter N = 4;

    logic clk;
    logic rst_n;
    logic start;
    logic done;
    logic signed [N-1:0][31:0] y_out;

    integer i;
    integer fd;
    integer cycles;
    string out_hex;
    string out_cyc;

    linear_relu #(
        .N          (N),
        .DATA_WIDTH (8)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .done  (done),
        .y_out (y_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        out_hex = "results/rtl_output.hex";
        out_cyc = "results/rtl_cycles.txt";
        void'($value$plusargs("out_hex=%s", out_hex));
        void'($value$plusargs("out_cyc=%s", out_cyc));

        rst_n  = 1'b0;
        start  = 1'b0;
        cycles = 0;
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
                $display("TIMEOUT waiting for done N=%0d", N);
                $finish;
            end
        end

        fd = $fopen(out_hex, "w");
        if (fd == 0) begin
            $display("ERROR: cannot open %s", out_hex);
            $finish;
        end
        for (i = 0; i < N; i = i + 1) begin
            $fdisplay(fd, "%08h", y_out[i]);
            $display("N=%0d y[%0d] = %0d", N, i, y_out[i]);
        end
        $fclose(fd);

        fd = $fopen(out_cyc, "w");
        $fdisplay(fd, "%0d", cycles);
        $fclose(fd);
        $display("tb_linear_relu_n N=%0d finished in %0d cycles", N, cycles);
        #20;
        $finish;
    end

endmodule
