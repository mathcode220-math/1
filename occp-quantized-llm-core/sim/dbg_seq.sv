`timescale 1ns/1ps
module dbg_seq;
    logic clk=0, rst_n;
    logic host_start;
    logic [63:0] metadata_in;
    logic metadata_valid;
    logic layer_done, softmax_done, weight_ready;
    logic sel_external, capture_loop, start_layer, buf_sel, weight_load_en;
    logic [7:0] weight_layer_idx, layer_counter_out;
    logic output_token_valid, pipeline_busy;
    logic [3:0] state_out;
    always #5 clk = ~clk;
    occp_pipeline_fsm dut (.*);

    task automatic step(); @(negedge clk); @(posedge clk); #1; endtask

    initial begin
        $monitor("%0t st=%0d tok=%b pulse=%b arm=%b done_e=%b cur_last=%b cnt=%0d tot=%0d",
                 $time, state_out, output_token_valid, dut.token_pulse, dut.token_arm,
                 dut.done_edge, dut.current_is_last, layer_counter_out, dut.total_layers_reg);
        rst_n=0; host_start=0; metadata_valid=0; layer_done=0; softmax_done=0;
        weight_ready=0; metadata_in='0; metadata_in[7:0]=8'd1;
        #25 rst_n=1; step();
        @(negedge clk); host_start=1; metadata_valid=1;
        @(posedge clk); #1;
        @(negedge clk); host_start=0; metadata_valid=0;
        step();   // LOAD_META -> PREFETCH
        weight_ready=1;
        step();   // PREFETCH -> LOAD0
        step();   // LOAD0 -> COMPUTE
        step();   // COMPUTE -> WAIT_DONE
        $display("---- now in WAIT_DONE st=%0d", state_out);
        @(negedge clk); layer_done=1; softmax_done=1;
        @(posedge clk); #1;
        $display("---- after done edge st=%0d tok=%b", state_out, output_token_valid);
        layer_done=0; softmax_done=0;
        step();
        $display("---- next st=%0d tok=%b", state_out, output_token_valid);
        $finish;
    end
endmodule
