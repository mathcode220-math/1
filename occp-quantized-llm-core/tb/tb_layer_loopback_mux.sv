`timescale 1ns/1ps

module tb_layer_loopback_mux;

    localparam int DATA_WIDTH = 8;
    localparam int VECTOR_LEN = 4;

    logic                       sel_external;
    logic [DATA_WIDTH-1:0]      ext_data  [0:VECTOR_LEN-1];
    logic                       ext_valid;
    logic [DATA_WIDTH-1:0]      loop_data [0:VECTOR_LEN-1];
    logic                       loop_valid;
    // DUT outputs are connected with wires — see the RTL compatibility note
    wire logic [DATA_WIDTH-1:0] mux_data  [0:VECTOR_LEN-1];
    wire logic                  mux_valid;

    layer_loopback_mux #(
        .DATA_WIDTH(DATA_WIDTH),
        .VECTOR_LEN(VECTOR_LEN)
    ) dut (.*);

    int error_count = 0;

    task automatic check_valid(string name, logic exp_valid);
        if (mux_valid !== exp_valid) begin
            $error("[%s] mux_valid = %b, expected %b", name, mux_valid, exp_valid);
            error_count++;
        end
    endtask

    initial begin
        #1; // step past time 0
        // initialize
        ext_data[0] = 8'hAA; ext_data[1] = 8'hBB; ext_data[2] = 8'hCC; ext_data[3] = 8'hDD;
        loop_data[0] = 8'h11; loop_data[1] = 8'h22; loop_data[2] = 8'h33; loop_data[3] = 8'h44;
        ext_valid = 1'b1;
        loop_valid = 1'b1;

        // Test 1: external path
        sel_external = 1'b1;
        #1;
        for (int i = 0; i < VECTOR_LEN; i++)
            if (mux_data[i] !== ext_data[i]) begin
                $error("[external_path] mux_data[%0d] = %h, expected %h", i, mux_data[i], ext_data[i]);
                error_count++;
            end
        check_valid("external_path", 1'b1);

        // Test 2: loopback path
        sel_external = 1'b0;
        #1;
        for (int i = 0; i < VECTOR_LEN; i++)
            if (mux_data[i] !== loop_data[i]) begin
                $error("[loop_path] mux_data[%0d] = %h, expected %h", i, mux_data[i], loop_data[i]);
                error_count++;
            end
        check_valid("loop_path", 1'b1);

        // Test 3: ext_valid=0 with sel=1
        ext_valid = 1'b0;
        sel_external = 1'b1;
        #1;
        for (int i = 0; i < VECTOR_LEN; i++)
            if (mux_data[i] !== ext_data[i]) begin
                $error("[ext_invalid] mux_data[%0d] = %h, expected %h", i, mux_data[i], ext_data[i]);
                error_count++;
            end
        check_valid("ext_invalid", 1'b0);

        // Test 4: loop_valid=0 with sel=0
        loop_valid = 1'b0;
        sel_external = 1'b0;
        #1;
        for (int i = 0; i < VECTOR_LEN; i++)
            if (mux_data[i] !== loop_data[i]) begin
                $error("[loop_invalid] mux_data[%0d] = %h, expected %h", i, mux_data[i], loop_data[i]);
                error_count++;
            end
        check_valid("loop_invalid", 1'b0);

        if (error_count == 0)
            $display("PASS: tb_layer_loopback_mux - all tests passed");
        else
            $error("FAIL: tb_layer_loopback_mux - %0d errors", error_count);

        $finish;
    end

endmodule
