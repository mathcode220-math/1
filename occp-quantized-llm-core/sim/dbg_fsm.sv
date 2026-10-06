`timescale 1ns/1ps
module dbg;
    logic clk=0, rst_n;
    logic host_start, metadata_valid, layer_done, softmax_done, weight_ready;
    logic [63:0] metadata_in;
    logic sel_external, capture_loop, start_layer, buf_sel, weight_load_en;
    logic [7:0] weight_layer_idx, layer_counter_out;
    logic output_token_valid, pipeline_busy;
    logic [3:0] state_out;
    always #5 clk = ~clk;
    occp_pipeline_fsm dut (.*);
    initial begin
        rst_n=0; host_start=0; metadata_valid=0; layer_done=0; softmax_done=0; weight_ready=0; metadata_in='0;
        @(negedge clk); rst_n=1;
        // T2
        host_start=1; @(negedge clk); @(posedge clk); #1; host_start=0;
        $display("after T2: state=%0d cnt=%0d", state_out, layer_counter_out);
        metadata_in[7:0]=8'd3; metadata_valid=1; @(negedge clk); @(posedge clk); #1; metadata_valid=0;
        $display("after T3: state=%0d cnt=%0d total=%0d", state_out, layer_counter_out, dut.total_layers_reg);
        weight_ready=1; @(negedge clk); @(posedge clk); #1; weight_ready=0;
        $display("after T4 compute: state=%0d cnt=%0d started=%b rc=%0d", state_out, layer_counter_out, dut.started, dut.running_count);
        @(negedge clk); @(posedge clk); #1;
        $display("T4 wait: state=%0d cnt=%0d rc=%0d started=%b", state_out, layer_counter_out, dut.running_count, dut.started);
        // middle layer L1
        layer_done=1; @(negedge clk); @(posedge clk); #1; layer_done=0;
        $display("mid loop-check: state=%0d cnt=%0d is_last=%b", state_out, layer_counter_out, dut.is_last_layer);
        @(negedge clk); @(posedge clk); #1;
        $display("mid prefetch: state=%0d cnt=%0d", state_out, layer_counter_out);
        weight_ready=1; @(negedge clk); @(posedge clk); #1; weight_ready=0;
        $display("mid compute: state=%0d cnt=%0d", state_out, layer_counter_out);
        @(negedge clk); @(posedge clk); #1;
        $display("mid wait: state=%0d cnt=%0d", state_out, layer_counter_out);
        // last layer L2
        layer_done=1; @(negedge clk); @(posedge clk); #1; layer_done=0;
        $display("last loop-check: state=%0d cnt=%0d is_last=%b", state_out, layer_counter_out, dut.is_last_layer);
        @(negedge clk); @(posedge clk); #1;
        $display("after edge: state=%0d cnt=%0d is_last=%b cap=%b", state_out, layer_counter_out, dut.is_last_layer, capture_loop);
        #1;
        $display("still: state=%0d", state_out);
        $finish;
    end
endmodule
