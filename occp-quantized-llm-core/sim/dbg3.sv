`timescale 1ns/1ps
module dbg3;
    logic clk=0, rst_n;
    logic host_start, metadata_valid;
    logic [63:0] metadata_in;
    logic layer_done, softmax_done, weight_ready;
    logic sel_external, capture_loop, start_layer, buf_sel, weight_load_en;
    logic [7:0] weight_layer_idx, layer_counter_out;
    logic output_token_valid, pipeline_busy;
    logic [3:0] state_out;
    always #5 clk = ~clk;
    occp_pipeline_fsm dut (.*);
    int cyc = 0;
    initial begin
        $display("cyc st run tot pend pulse ldone sdone wready");
        rst_n=0; host_start=0; metadata_valid=0; metadata_in='0;
        layer_done=0; softmax_done=0; weight_ready=0;
        #25 rst_n=1;
        @(negedge clk); host_start=1; metadata_in[7:0]=8'd3; metadata_valid=1;
        @(posedge clk); #1;
        @(negedge clk); host_start=0; metadata_valid=0;
        repeat (40) begin
            $display("%3d %0d %0d %0d %b %b %b %b %b",
                cyc, state_out, dut.running_count, dut.total_layers_reg,
                dut.token_pending, dut.token_pulse, layer_done, softmax_done, weight_ready);
            cyc++;
            @(negedge clk);
            // drive simple stimulus
            if (state_out==4'd2) weight_ready=1; else weight_ready=0;
            if (state_out==4'd5) begin layer_done=1; softmax_done=1; end
            else begin layer_done=0; softmax_done=0; end
            @(posedge clk); #1;
        end
        $finish;
    end
endmodule
