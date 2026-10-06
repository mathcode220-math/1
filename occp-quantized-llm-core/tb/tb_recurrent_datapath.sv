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

    // Watchdog: fail the test instead of hanging forever
    initial begin
        #5000;
        $error("FAIL: watchdog timeout");
        $finish;
    end

    // One full layer: start pulse, wait for done, settle edge + readout
    task automatic run_layer(input logic use_external, input logic capture);
        @(negedge clk);
        sel_external = use_external;
        capture_loop = capture;
        start_layer  = 1'b1;
        @(negedge clk);
        start_layer  = 1'b0;
        wait (layer_done === 1'b1);   // layer is about to finish computing
        @(posedge clk);               // settle edge: layer_flat stabilizes
        // Icarus note: array-port draining across port ranges
        // happens after # delays, so read fields at the edge instant
        check_data = dut.final_data[0];
        check_data3 = dut.final_data[3];
    endtask

    logic [DATA_WIDTH-1:0] check_data, check_data3;

    initial begin
        rst_n = 0;
        sel_external = 1;
        capture_loop = 0;
        start_layer = 0;
        ext_valid = 0;
        for (int i = 0; i < VECTOR_LEN; i++) ext_data[i] = '0;

        #12 rst_n = 1;

        // Layer 0: from the external path — captured into the loop register
        @(negedge clk);
        ext_data[0] = 8'h42; ext_data[1] = 8'h43;
        ext_data[2] = 8'h44; ext_data[3] = 8'h45;
        ext_valid = 1;
        @(negedge clk);           // drive inputs before the start pulse

        run_layer(1'b1, 1'b1);
        $display("T=%0t: layer 0 done, data=%h", $time, check_data);
        if (check_data !== 8'h42 || check_data3 !== 8'h45) begin
            $error("layer 0: got %h/%h, expected 42/45", check_data, check_data3);
            error_count++;
        end

        // Layer 1: from the loopback path (loop_valid captured from layer 0)
        run_layer(1'b0, 1'b0);
        $display("T=%0t: layer 1 done, data=%h valid=%b",
                 $time, check_data, final_valid);
        if (check_data !== 8'h42 || final_valid !== 1'b1) begin
            $error("layer 1 loopback: got %h valid=%b, expected 42/1",
                   check_data, final_valid);
            error_count++;
        end else begin
            $display("PASS: loop works - data circulated through two layers");
        end

        if (error_count == 0)
            $display("PASS: tb_recurrent_datapath - all tests passed");
        else
            $error("FAIL: tb_recurrent_datapath: %0d errors", error_count);

        $finish;
    end

endmodule
