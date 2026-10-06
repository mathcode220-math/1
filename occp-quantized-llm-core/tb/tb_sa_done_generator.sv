`timescale 1ns/1ps

module tb_sa_done_generator;

    localparam int LATENCY_WIDTH = 8;

    logic                       clk = 0;
    logic                       rst_n;
    logic                       start;
    logic [LATENCY_WIDTH-1:0]   latency_cfg;
    wire  logic                 done;

    always #5 clk = ~clk;

    sa_done_generator #(
        .LATENCY_WIDTH(LATENCY_WIDTH)
    ) dut (.*);

    int cycle_count;
    int error_count = 0;

    initial begin
        #1;
        rst_n = 0;
        start = 0;
        latency_cfg = 8'd5;
        #11 rst_n = 1;

        // Test 1: start pulse with LATENCY=5
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);           // start is registered on the next edge
        start = 1'b0;

        cycle_count = 0;
        while (!done && cycle_count < 20) begin
            @(posedge clk); #1;
            cycle_count++;
        end

        if (!done) begin
            $error("done was not issued within 20 cycles");
            error_count++;
        end else if (cycle_count != 5) begin
            $error("cycle count = %0d, expected 5", cycle_count);
            error_count++;
        end else begin
            $display("OK: done issued after %0d cycles (expected 5)", cycle_count);
        end

        // Test 2: new start after the first completes
        @(negedge clk);
        latency_cfg = 8'd3;
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        cycle_count = 0;
        while (!done && cycle_count < 10) begin
            @(posedge clk); #1;
            cycle_count++;
        end
        if (cycle_count != 3) begin
            $error("test2: cycle count = %0d, expected 3", cycle_count);
            error_count++;
        end

        if (error_count == 0)
            $display("PASS: tb_sa_done_generator - all tests passed");
        else
            $error("FAIL: tb_sa_done_generator - %0d errors", error_count);

        $finish;
    end

endmodule
