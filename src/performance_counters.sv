//============================================================================
//  SILICON AGENT: Performance Counters Module
//  Tracks learning progress, convergence metrics, and statistics
//============================================================================

`include "agent_types.svh"

module performance_counters #(
    parameter int NUM_TOKENS = 5,
    parameter int DATA_WIDTH = 16,
    parameter int CONV_THRESHOLD = 100  // Cycles of stability for convergence
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  enable,
    
    // Learning signals
    input  logic                  update_valid,
    input  logic [$clog2(NUM_TOKENS)-1:0] winner_id,
    input  logic signed [DATA_WIDTH-1:0]  bias [NUM_TOKENS-1:0],
    input  logic signed [DATA_WIDTH-1:0]  q_values [NUM_TOKENS-1:0],
    
    // Convergence detection
    output logic                  converged,
    output logic [31:0]           cycles_to_converge,
    
    // Output statistics
    output perf_counters_t        counters_out
);
    // Internal registers
    logic [31:0] total_cycles_reg;
    logic [31:0] total_updates_reg;
    logic [31:0] winner_counts_reg [NUM_TOKENS-1:0];
    logic [15:0] final_bias_reg [NUM_TOKENS-1:0];
    logic [15:0] final_q_reg [NUM_TOKENS-1:0];
    logic [31:0] stable_cycles_reg;
    logic [31:0] last_winner_reg;
    logic converged_reg;
    
    integer i;
    
    // ------------------------------------------------------------------------
    // Total Cycle Counter
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            total_cycles_reg <= '0;
        else if (enable)
            total_cycles_reg <= total_cycles_reg + 1'b1;
    end
    
    // ------------------------------------------------------------------------
    // Update Counter and Winner Statistics
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_updates_reg <= '0;
            for (i = 0; i < NUM_TOKENS; i = i + 1)
                winner_counts_reg[i] <= '0;
        end else if (update_valid && enable) begin
            total_updates_reg <= total_updates_reg + 1'b1;
            winner_counts_reg[winner_id] <= winner_counts_reg[winner_id] + 1'b1;
        end
    end
    
    // ------------------------------------------------------------------------
    // Final Bias and Q-Value Storage
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_TOKENS; i = i + 1) begin
                final_bias_reg[i] <= '0;
                final_q_reg[i] <= '0;
            end
        end else if (enable) begin
            for (i = 0; i < NUM_TOKENS; i = i + 1) begin
                final_bias_reg[i] <= bias[i][15:0];
                final_q_reg[i] <= q_values[i][15:0];
            end
        end
    end
    
    // ------------------------------------------------------------------------
    // Convergence Detection
    // Convergence = same winner for CONV_THRESHOLD consecutive cycles
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stable_cycles_reg <= '0;
            last_winner_reg <= '0;
            converged_reg <= 1'b0;
        end else if (enable) begin
            if (winner_id == last_winner_reg) begin
                stable_cycles_reg <= stable_cycles_reg + 1'b1;
                if (stable_cycles_reg >= CONV_THRESHOLD)
                    converged_reg <= 1'b1;
            end else begin
                stable_cycles_reg <= '0;
                last_winner_reg <= winner_id;
                converged_reg <= 1'b0;
            end
        end
    end
    
    assign cycles_to_converge = converged_reg ? 
        (total_cycles_reg - stable_cycles_reg) : total_cycles_reg;
    
    // ------------------------------------------------------------------------
    // Output Assignment
    // ------------------------------------------------------------------------
    assign counters_out.total_cycles = total_cycles_reg;
    assign counters_out.total_updates = total_updates_reg;
    
    genvar g;
    generate
        for (g = 0; g < NUM_TOKENS; g = g + 1) begin : winner_count_gen
            assign counters_out.winner_counts[g] = winner_counts_reg[g];
            assign counters_out.final_bias[g] = final_bias_reg[g];
            assign counters_out.final_q[g] = final_q_reg[g];
        end
    endgenerate
    
    assign counters_out.converged = converged_reg;
    assign counters_out.cycles_to_converge = cycles_to_converge;
    
    assign converged = converged_reg;
    
    // ------------------------------------------------------------------------
    // SVA: Verify counter behavior
    // ------------------------------------------------------------------------
    property p_winner_count_sum;
        @(posedge clk) disable iff (!rst_n)
        (converged) |-> 
        (winner_counts_reg[0] + winner_counts_reg[1] + winner_counts_reg[2] + 
         winner_counts_reg[3] + winner_counts_reg[4] == total_updates_reg);
    endproperty
    
    assert property (p_winner_count_sum)
        else $warning("Perf: Winner count mismatch detected");
    
    // SVA: Convergence should only happen after sufficient updates
    property p_convergence_after_updates;
        @(posedge clk) disable iff (!rst_n)
        converged |-> (total_updates_reg > NUM_TOKENS * 10);
    endproperty
    
    assert property (p_convergence_after_updates)
        else $warning("Perf: Premature convergence detected");
endmodule
