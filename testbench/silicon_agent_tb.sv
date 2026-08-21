//============================================================================
//  SILICON AGENT: Modular Testbench with Coverage Collection
//  Separated from RTL for reusability and maintainability
//============================================================================

`timescale 1ns/1ps

module silicon_agent_tb;
    
    // ========================================================================
    // Parameters (can be overridden for different configurations)
    // ========================================================================
    localparam int NUM_TOKENS = 5;
    localparam int WIDTH = 16;
    localparam int BITSTREAM_LEN = 256;
    localparam int DIM = 8;
    localparam int CLK_FAST_PERIOD = 10;   // 100 MHz
    localparam int CLK_SLOW_PERIOD = 50;   // 20 MHz (for learning)
    localparam int NUM_TEST_CYCLES = 600;
    localparam int EXPECTED_WINNER = 2;    // Token 2 has best V_quality
    
    // ========================================================================
    // Clock and Reset Signals
    // ========================================================================
    logic clk_fast;
    logic clk_slow;
    logic rst_n;
    
    // ========================================================================
    // DUT Signals
    // ========================================================================
    logic signed [WIDTH-1:0] evidence [NUM_TOKENS-1:0][NUM_TOKENS-1:0];
    logic [BITSTREAM_LEN-1:0] V_streams [NUM_TOKENS-1:0][DIM-1:0];
    logic eval_trigger;
    logic signed [WIDTH-1:0] target_value;
    logic [BITSTREAM_LEN-1:0] output_streams [NUM_TOKENS-1:0][DIM-1:0];
    logic [NUM_TOKENS-1:0] attention_weights [NUM_TOKENS-1:0];
    logic [$clog2(NUM_TOKENS)-1:0] winner_ids [NUM_TOKENS-1:0];
    
    // Learning signals (internal monitoring)
    logic learn_write_en;
    logic [$clog2(NUM_TOKENS)-1:0] learn_write_addr;
    logic signed [WIDTH-1:0] learn_write_data;
    logic reward_valid;
    logic signed [WIDTH-1:0] reward_value;
    
    // Convergence monitoring
    logic converged;
    
    // ========================================================================
    // Testbench Variables
    // ========================================================================
    integer cycle;
    integer token, dim, bit_idx;
    integer win_count [NUM_TOKENS-1:0];
    integer total_updates;
    real v_qualities [NUM_TOKENS-1:0];
    
    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        $display("[%0t] Starting clock generation", $time);
        clk_fast = 0;
        clk_slow = 0;
        forever begin
            #(CLK_FAST_PERIOD/2) clk_fast = ~clk_fast;
        end
    end
    
    initial begin
        forever begin
            #(CLK_SLOW_PERIOD/2) clk_slow = ~clk_slow;
        end
    end
    
    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    silicon_agent_top #(
        .WIDTH(WIDTH),
        .BITSTREAM_LEN(BITSTREAM_LEN),
        .NUM_TOKENS(NUM_TOKENS),
        .DIM(DIM)
    ) dut (
        .clk(clk_fast),
        .rst_n(rst_n),
        .evidence(evidence),
        .V_streams(V_streams),
        .eval_trigger(eval_trigger),
        .target_value(target_value),
        .output_streams(output_streams),
        .attention_weights(attention_weights),
        .winner_ids(winner_ids)
    );
    
    // ========================================================================
    // Assertions Instance
    // ========================================================================
    agent_assertions #(.NUM_TOKENS(NUM_TOKENS), .DATA_WIDTH(WIDTH)) assertions_inst (
        .clk(clk_fast),
        .rst_n(rst_n),
        .bias(),  // Connect to internal signals if needed
        .q_values(),
        .winner_id(winner_ids[0]),
        .one_hot_weights(attention_weights[0]),
        .reward_valid(reward_valid),
        .eval_trigger(eval_trigger),
        .update_en(learn_write_en),
        .converged(converged),
        .reward(reward_value)
    );
    
    // ========================================================================
    // Task: Generate Stochastic Bitstream
    // ========================================================================
    task automatic generate_bitstream(
        input real prob,
        output logic [BITSTREAM_LEN-1:0] stream
    );
        integer b;
        real rand_val;
        begin
            for (b = 0; b < BITSTREAM_LEN; b = b + 1) begin
                rand_val = $urandom_range(0, 1000) / 1000.0;
                stream[b] = (rand_val < prob) ? 1'b1 : 1'b0;
            end
        end
    endtask
    
    // ========================================================================
    // Task: Reset DUT
    // ========================================================================
    task automatic reset_dut();
        begin
            $display("[%0t] Asserting reset", $time);
            rst_n = 1'b0;
            eval_trigger = 1'b0;
            
            // Initialize evidence to neutral values
            for (token = 0; token < NUM_TOKENS; token = token + 1)
                for (integer t2 = 0; t2 < NUM_TOKENS; t2 = t2 + 1)
                    evidence[token][t2] = 16'd50;
            
            #(CLK_FAST_PERIOD * 5);
            rst_n = 1'b1;
            #(CLK_FAST_PERIOD * 2);
            $display("[%0t] Release reset", $time);
        end
    endtask
    
    // ========================================================================
    // Task: Apply Random Evidence
    // ========================================================================
    task automatic apply_random_evidence();
        begin
            for (token = 0; token < NUM_TOKENS; token = token + 1)
                for (integer t2 = 0; t2 < NUM_TOKENS; t2 = t2 + 1)
                    evidence[token][t2] = $urandom_range(40, 60);
        end
    endtask
    
    // ========================================================================
    // Task: Check Convergence
    // ========================================================================
    task automatic check_convergence(input int expected_winner);
        integer threshold;
        begin
            threshold = NUM_TEST_CYCLES * 60 / 100;  // 60% threshold
            
            $display("");
            $display("============================================================");
            $display("  FINAL REPORT (Last %0d cycles)", NUM_TEST_CYCLES - 100);
            $display("============================================================");
            
            for (token = 0; token < NUM_TOKENS; token = token + 1) begin
                $display("  Token %0d win count: %0d (%0.1f%%)", 
                         token, win_count[token], 
                         100.0 * win_count[token] / (NUM_TEST_CYCLES - 100));
            end
            
            if (win_count[expected_winner] > threshold) begin
                $display("  PASS: Token %0d dominates (learned best policy!)", expected_winner);
            end else begin
                $display("  FAIL: Token %0d did not learn to dominate (count=%0d, threshold=%0d)", 
                         expected_winner, win_count[expected_winner], threshold);
            end
            
            $display("============================================================");
        end
    endtask
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        $display("============================================================");
        $display("  SILICON AGENT: Modular Testbench");
        $display("  Target: Token 2 should emerge as winner (best V quality)");
        $display("  Configuration:");
        $display("    NUM_TOKENS     = %0d", NUM_TOKENS);
        $display("    DATA_WIDTH     = %0d", WIDTH);
        $display("    BITSTREAM_LEN  = %0d", BITSTREAM_LEN);
        $display("    DIM            = %0d", DIM);
        $display("============================================================");
        
        // Initialize coverage group
        cov_group = new();
        
        // Initialize variables
        target_value = 200;  // ~78% of 256
        for (token = 0; token < NUM_TOKENS; token = token + 1)
            win_count[token] = 0;
        total_updates = 0;
        
        // Set V qualities (Token 2 is best)
        v_qualities[0] = 0.55;
        v_qualities[1] = 0.52;
        v_qualities[2] = 0.80;  // BEST
        v_qualities[3] = 0.50;
        v_qualities[4] = 0.30;  // WORST
        
        // Reset DUT
        reset_dut();
        
        // Run learning cycles
        $display("[%0t] Starting learning cycles...", $time);
        for (cycle = 0; cycle < NUM_TEST_CYCLES; cycle = cycle + 1) begin
            // Generate V_streams with different quality per token
            for (token = 0; token < NUM_TOKENS; token = token + 1) begin
                for (dim = 0; dim < DIM; dim = dim + 1)
                    generate_bitstream(v_qualities[token], V_streams[token][dim]);
            end
            
            // Trigger evaluation every 5 cycles (slow critic)
            eval_trigger = (cycle % 5 == 0) ? 1'b1 : 1'b0;
            
            @(posedge clk_fast);
            #1;  // Small delay for combinational settling
            
            // Monitor winner after initial exploration phase
            if (cycle > 100) begin
                win_count[winner_ids[0]] = win_count[winner_ids[0]] + 1;
            end
            
            // Count updates
            if (learn_write_en)
                total_updates = total_updates + 1;
            
            // Sample coverage
            if (cov_group != null) begin
                cov_group.sample();
            end
            
            // Display progress every 100 cycles
            if (cycle % 100 == 0 && cycle > 0) begin
                $display("  Cycle %0d: Winner = Token %0d, Updates = %0d", 
                         cycle, winner_ids[0], total_updates);
            end
        end
        
        // Check convergence
        check_convergence(EXPECTED_WINNER);
        
        // Display coverage report
        $display("");
        $display("============================================================");
        $display("  COVERAGE REPORT");
        $display("============================================================");
        if (cov_group != null) begin
            $display("  Overall coverage: %0.1f%%", cov_group.get_coverage());
            cov_group.report();
        end
        $display("============================================================");
        
        $finish;
    end
    
    // ========================================================================
    // Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("silicon_agent.vcd");
        $dumpvars(0, silicon_agent_tb);
    end
    
    // ========================================================================
    // Finish Simulation on Error or Timeout
    // ========================================================================
    initial begin
        #(NUM_TEST_CYCLES * CLK_FAST_PERIOD * 2);
        $display("[%0t] Simulation timeout reached", $time);
        $finish;
    end
    
endmodule
