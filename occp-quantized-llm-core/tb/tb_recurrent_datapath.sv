`timescale 1ns/1ps

module tb_recurrent_datapath;

    localparam int DATA_WIDTH = 8;
    localparam int VECTOR_LEN = 4;

    logic                    clk = 0;
    logic                    rst_n;
    logic                    sel_external;
    logic                    capture_loop;
    logic                    start_layer;
    logic                    layer_done;
    logic [DATA_WIDTH-1:0]   ext_data  [0:VECTOR_LEN-1];
    logic                    ext_valid;
    logic [DATA_WIDTH-1:0]   final_data [0:VECTOR_LEN-1];
    logic                    final_valid;

    always #5 clk = ~clk;

    recurrent_datapath #(
        .DATA_WIDTH(DATA_WIDTH),
        .VECTOR_LEN(VECTOR_LEN)
    ) dut (.*);

    int error_count = 0;

    initial begin
        rst_n = 0;
        sel_external = 1;
        capture_loop = 0;
        start_layer = 0;
        ext_valid = 0;
        for (int i = 0; i < VECTOR_LEN; i++) ext_data[i] = '0;

        #12 rst_n = 1;

        // نبضة إدخال
        @(negedge clk);
        ext_data[0] = 8'h42; ext_data[1] = 8'h43;
        ext_data[2] = 8'h44; ext_data[3] = 8'h45;
        ext_valid = 1;

        // دورة 1: الطبقة 0 (external)
        @(negedge clk);
        start_layer = 1;
        @(negedge clk);
        start_layer = 0;

        // انتظار layer_done
        wait (layer_done);
        @(posedge clk); #1;
        $display("T=%0t: layer 0 done, final_data[0]=%h", $time, final_data[0]);

        // التقاط مخرج الطبقة الأولى في سجل الحلقة
        @(negedge clk);
        capture_loop = 1;
        @(negedge clk); #1;

        // دورة 2: الطبقة 1 (loopback)
        @(negedge clk);
        sel_external = 0;
        start_layer = 1;
        @(negedge clk);
        start_layer = 0;

        wait (layer_done);
        @(posedge clk); #1;
        $display("T=%0t: layer 1 done, final_data[0]=%h", $time, final_data[0]);

        if (final_data[0] === 8'h42)
            $display("PASS: loop works - data circulated through two layers");
        else begin
            $error("FAIL loop: final_data[0]=%h, expected 42", final_data[0]);
            error_count++;
        end

        if (error_count == 0)
            $display("PASS: tb_recurrent_datapath - all tests passed");
        else
            $error("FAIL: tb_recurrent_datapath: %0d errors", error_count);

        $finish;
    end

endmodule
