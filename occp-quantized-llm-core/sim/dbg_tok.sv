`timescale 1ns/1ps
module dbg_tok;
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
    initial begin
        rst_n=0; host_start=0; metadata_valid=0; layer_done=0; softmax_done=0;
        weight_ready=0; metadata_in='0; metadata_in[7:0]=8'd1;
        #25 rst_n=1; @(negedge clk);
        host_start=1; metadata_valid=1; @(posedge clk); #1;
        @(negedge clk); host_start=0; metadata_valid=0; weight_ready=1;
        // walk: LOAD_META -> PREFETCH -> LOAD0 -> COMPUTE -> WAIT
        repeat(4) @(negedge clk);
        // now in WAIT_DONE presumably; assert done for one negedge window
        layer_done=1; softmax_done=1;
        @(posedge clk); #1;
        layer_done=0; softmax_done=0;
        $display("after done edge: state=%0d tok=%b pulse=%b pend=%b cnt=%0d", state_out, output_token_valid, dut.token_pulse, dut.token_pending, layer_counter_out);
        @(posedge clk); #1;
        $display("next edge:      state=%0d tok=%b pulse=%b pend=%b cnt=%0d", state_out, output_token_valid, dut.token_pulse, dut.token_pending, layer_counter_out);
        @(posedge clk); #1;
        $display("third edge:     state=%0d tok=%b pulse=%b pend=%b cnt=%0d", state_out, output_token_valid, dut.token_pulse, dut.token_pending, layer_counter_out);
        $finish;
    end
endmodule
