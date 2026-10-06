//=============================================================================
// tb_linear_relu.sv
// Why this file exists: command 4.2 — drive linear_relu_4x4 and write
// results/rtl_output.hex plus results/rtl_cycles.txt.
//=============================================================================

`timescale 1ns/1ps

module tb_linear_relu;

    localparam N = 4;

    logic clk;
    logic rst_n;
    logic start;
    logic done;
    logic signed [N-1:0][31:0] y_out;

    integer i;
    integer fd;
    integer cycles;

    linear_relu_4x4 #(
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
            if (cycles > 500) begin
                $display("TIMEOUT waiting for done");
                $finish;
            end
        end

        fd = $fopen("results/rtl_output.hex", "w");
        if (fd == 0) begin
            $display("ERROR: cannot open results/rtl_output.hex");
            $finish;
        end
        for (i = 0; i < N; i = i + 1) begin
            $fdisplay(fd, "%08h", y_out[i]);
            $display("y[%0d] = %0d", i, y_out[i]);
        end
        $fclose(fd);

        fd = $fopen("results/rtl_cycles.txt", "w");
        $fdisplay(fd, "%0d", cycles);
        $fclose(fd);
        $display("tb_linear_relu finished in %0d cycles", cycles);
        #20;
        $finish;
    end

endmodule
