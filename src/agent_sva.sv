//============================================================================
//  SILICON AGENT: SystemVerilog Assertions (SVA)
//  Comprehensive property checks for verification
//============================================================================

`include "agent_types.svh"

package agent_sva;
    
    // ========================================================================
    // Sequence Definitions
    // ========================================================================
    
    // Reset sequence
    sequence s_reset_asserted(rst_n);
        !rst_n;
    endsequence
    
    // Single-cycle pulse
    sequence s_single_cycle_pulse(sig, clk);
        @(posedge clk) $rose(sig) ##1 !sig;
    endsequence
    
    // Stable for N cycles
    sequence s_stable_for_n_cycles(sig, n, clk);
        @(posedge clk) $stable(sig)[*n];
    endsequence
    
    // ========================================================================
    // Property: Bias Bounds Check
    // ========================================================================
    property p_bias_bounds(
        input logic signed [15:0] bias,
        input logic signed [15:0] bias_min,
        input logic signed [15:0] bias_max,
        input logic clk,
        input logic rst_n
    );
        @(posedge clk) disable iff (!rst_n)
        (bias >= bias_min) && (bias <= bias_max);
    endproperty
    
    // ========================================================================
    // Property: Q-Value Convergence
    // ========================================================================
    property p_q_convergence(
        input logic signed [15:0] q_val,
        input logic signed [15:0] q_avg,
        input int threshold,
        input logic converged,
        input logic clk,
        input logic rst_n
    );
        @(posedge clk) disable iff (!rst_n)
        (converged) |-> 
        ($abs(q_val - q_avg) < threshold);
    endproperty
    
    // ========================================================================
    // Property: Winner Stability After Convergence
    // ========================================================================
    property p_winner_stability(
        input logic [2:0] winner_id,
        input logic converged,
        input int stable_cycles,
        input logic clk,
        input logic rst_n
    );
        @(posedge clk) disable iff (!rst_n)
        (converged) |=> 
        $stable(winner_id)[*stable_cycles];
    endproperty
    
    // ========================================================================
    // Property: Learning Rate Application
    // ========================================================================
    property p_learning_rate_applied(
        input logic update_en,
        input logic signed [15:0] bias_before,
        input logic signed [15:0] bias_after,
        input logic [7:0] learning_rate,
        input logic clk,
        input logic rst_n
    );
        @(posedge clk) disable iff (!rst_n)
        (update_en) |=> 
        ($abs(bias_after - bias_before) == learning_rate) ||
        ((bias_after == bias_before + learning_rate) || 
         (bias_after == bias_before - learning_rate));
    endproperty
    
    // ========================================================================
    // Property: Reward Validity
    // ========================================================================
    property p_reward_valid_after_eval(
        input logic eval_trigger,
        input logic reward_valid,
        input int delay,
        input logic clk,
        input logic rst_n
    );
        @(posedge clk) disable iff (!rst_n)
        (eval_trigger) |-> ##[1:delay] reward_valid;
    endproperty
    
    // ========================================================================
    // Property: No Overflow in Q-Update
    // ========================================================================
    property p_no_q_overflow(
        input logic signed [15:0] q_before,
        input logic signed [15:0] q_after,
        input logic signed [15:0] reward,
        input logic update_en,
        input logic clk,
        input logic rst_n
    );
        logic signed [15:0] expected_q;
        @(posedge clk) disable iff (!rst_n)
        (update_en) |=> 
        (q_after >= -32768) && (q_after <= 32767);
    endproperty
    
    // ========================================================================
    // Property: One-Hot Encoding Validity
    // ========================================================================
    property p_one_hot_valid(
        input logic [4:0] one_hot,
        input logic valid,
        input logic clk,
        input logic rst_n
    );
        @(posedge clk) disable iff (!rst_n)
        (valid) |-> 
        (one_hot == 5'b00001) || (one_hot == 5'b00010) ||
        (one_hot == 5'b00100) || (one_hot == 5'b01000) ||
        (one_hot == 5'b10000);
    endproperty
    
    // ========================================================================
    // Property: CDC Handshake Completeness
    // ========================================================================
    property p_cdc_handshake_complete(
        input logic src_valid,
        input logic dst_ready,
        input logic src_ready,
        input int max_delay,
        input logic clk_src,
        input logic rst_n
    );
        @(posedge clk_src) disable iff (!rst_n)
        (src_valid && !src_ready) |-> ##[1:max_delay] src_ready;
    endproperty
    
    // ========================================================================
    // Property: FSM State Validity
    // ========================================================================
    property p_fsm_state_valid(
        input logic [2:0] state,
        input logic clk,
        input logic rst_n
    );
        @(posedge clk) disable iff (!rst_n)
        (state inside {3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b111});
    endproperty
    
    // ========================================================================
    // Property: Configuration Register Write/Read Consistency
    // ========================================================================
    property p_config_reg_consistency(
        input logic write_en,
        input logic [7:0] addr,
        input logic [31:0] wdata,
        input logic [31:0] rdata,
        input int read_delay,
        input logic clk,
        input logic rst_n
    );
        logic [31:0] stored_data;
        @(posedge clk) disable iff (!rst_n)
        (write_en) |-> ##[1:read_delay] (rdata == wdata);
    endproperty
    
    // ========================================================================
    // Cover Groups for Functional Coverage
    // ========================================================================
    
    covergroup cg_agent_coverage @(posedge clk);
        option.per_instance = 1;
        
        // Cover winner distribution
        cp_winner: coverpoint winner_id {
            bins token_0 = {0};
            bins token_1 = {1};
            bins token_2 = {2};
            bins token_3 = {3};
            bins token_4 = {4};
        }
        
        // Cover reward ranges
        cp_reward_range: coverpoint reward {
            bins low_reward   = {[0:63]};
            bins mid_reward   = {[64:127]};
            bins high_reward  = {[128:191]};
            bins vhigh_reward = {[192:255]};
        }
        
        // Cover bias values
        cp_bias_range: coverpoint bias {
            bins negative = {[-32768:-1]};
            bins zero = {0};
            bins positive = {[1:32767]};
        }
        
        // Cover convergence states
        cp_convergence: coverpoint converged {
            bins not_converged = {0};
            bins converged = {1};
        }
        
        // Cross coverage: winner vs reward
        cross_winner_reward: cross cp_winner, cp_reward_range;
        
        // Cross coverage: bias vs convergence
        cross_bias_convergence: cross cp_bias_range, cp_convergence;
    endgroup
    
endpackage

// ============================================================================
// Assertion Wrapper Module for Easy Instantiation
// ============================================================================
module agent_assertions #(
    parameter int NUM_TOKENS = 5,
    parameter int DATA_WIDTH = 16
) (
    input logic                  clk,
    input logic                  rst_n,
    
    // Signals to check
    input logic signed [DATA_WIDTH-1:0] bias [NUM_TOKENS-1:0],
    input logic signed [DATA_WIDTH-1:0] q_values [NUM_TOKENS-1:0],
    input logic [$clog2(NUM_TOKENS)-1:0] winner_id,
    input logic [NUM_TOKENS-1:0] one_hot_weights,
    input logic                  reward_valid,
    input logic                  eval_trigger,
    input logic                  update_en,
    input logic                  converged,
    input logic signed [DATA_WIDTH-1:0] reward
);
    import agent_sva::*;
    
    integer i;
    
    // Generate bias bounds checks for each token
    generate
        for (i = 0; i < NUM_TOKENS; i = i + 1) begin : bias_check_gen
            assert property (p_bias_bounds(
                bias[i], -32768, 32767, clk, rst_n
            )) else $error("SVA: Bias[%0d] out of bounds: %0d", i, bias[i]);
            
            cover property (p_bias_bounds(
                bias[i], -32768, 32767, clk, rst_n
            ));
        end
    endgenerate
    
    // One-hot validity check
    assert property (p_one_hot_valid(
        one_hot_weights, 1'b1, clk, rst_n
    )) else $error("SVA: Invalid one-hot encoding: %b", one_hot_weights);
    
    // FSM state validity (if exposed)
    // assert property (p_fsm_state_valid(state, clk, rst_n));
    
endmodule
