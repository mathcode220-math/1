`timescale 1ns/1ps

module tb_loopback_register;

    localparam int DATA_WIDTH = 8;
    localparam int VECTOR_LEN = 4;

    logic                   clk = 0;
    logic                   rst_n;
    logic                   en;
    logic [DATA_WIDTH-1:0]  data_in  [0:VECTOR_LEN-1];
    logic                   valid_in;
    wire  logic [DATA_WIDTH-1:0] data_out [0:VECTOR_LEN-1];
    wire  logic             valid_out;

    always #5 clk = ~clk;

    loopback_register #(
        .DATA_WIDTH(DATA_WIDTH),
        .VECTOR_LEN(VECTOR_LEN)
    ) dut (.*);

    int error_count = 0;

    initial begin
        #1;
        rst_n = 0;
        en = 0;
        valid_in = 0;
        for (int i = 0; i < VECTOR_LEN; i++) data_in[i] = '0;

        #11 rst_n = 1;

        // اختبار 1: التقاط البيانات
        @(negedge clk);
        data_in[0] = 8'h10; data_in[1] = 8'h20; data_in[2] = 8'h30; data_in[3] = 8'h40;
        valid_in = 1'b1;
        en = 1'b1;
        @(posedge clk); #1;
        if (data_out[0] !== 8'h10 || data_out[3] !== 8'h40 || valid_out !== 1'b1) begin
            $error("test1 failed: data_out(%h,%h) or valid_out(%b) incorrect",
                   data_out[0], data_out[3], valid_out);
            error_count++;
        end

        // اختبار 2: en=0 -> البيانات تبقى ثابتة
        @(negedge clk);
        data_in[0] = 8'hFF;
        valid_in = 1'b0;
        en = 1'b0;
        @(posedge clk); #1;
        if (data_out[0] !== 8'h10) begin
            $error("test2 failed: data changed while en=0 (%h)", data_out[0]);
            error_count++;
        end

        // اختبار 3: reset
        @(negedge clk); rst_n = 0;
        @(posedge clk); #1;
        if (data_out[0] !== 8'h00 || valid_out !== 1'b0) begin
            $error("test3 failed: reset did not work");
            error_count++;
        end

        if (error_count == 0)
            $display("PASS: tb_loopback_register - all tests passed");
        else
            $error("FAIL: tb_loopback_register - %0d errors", error_count);

        $finish;
    end

endmodule
