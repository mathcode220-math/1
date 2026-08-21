//============================================================================
//  SILICON AGENT: Saturation Arithmetic Utilities
//  Overflow protection for fixed-point arithmetic in learning algorithms
//============================================================================

`include "agent_types.svh"

// ============================================================================
// Saturating Adder: Prevents overflow in bias/Q-value updates
// ============================================================================
module saturating_adder #(
    parameter int WIDTH = 16
) (
    input  logic signed [WIDTH-1:0] a,
    input  logic signed [WIDTH-1:0] b,
    output logic signed [WIDTH-1:0] result,
    output logic                    overflow
);
    logic signed [WIDTH:0] full_result;
    
    assign full_result = {a[WIDTH-1], a} + {b[WIDTH-1], b};
    
    always_comb begin
        // Detect overflow: sign bit differs from extended sign
        if (full_result[WIDTH] != full_result[WIDTH-1]) begin
            overflow = 1'b1;
            // Saturate to max or min based on sign
            if (full_result[WIDTH-1] == 1'b0)
                result = {1'b0, {WIDTH-1{1'b1}}};  // MAX_POSITIVE
            else
                result = {1'b1, {WIDTH-1{1'b0}}};  // MIN_NEGATIVE
        end else begin
            overflow = 1'b0;
            result = full_result[WIDTH-1:0];
        end
    end
    
    // Note: SVA properties moved to agent_sva.sv package for better tool support
endmodule

// ============================================================================
// Saturating Subtractor: For reward difference calculations
// ============================================================================
module saturating_subtractor #(
    parameter int WIDTH = 16
) (
    input  logic signed [WIDTH-1:0] a,
    input  logic signed [WIDTH-1:0] b,
    output logic signed [WIDTH-1:0] result,
    output logic                    underflow
);
    logic signed [WIDTH:0] full_result;
    
    assign full_result = {a[WIDTH-1], a} - {b[WIDTH-1], b};
    
    always_comb begin
        if (full_result[WIDTH] != full_result[WIDTH-1]) begin
            underflow = 1'b1;
            if (full_result[WIDTH-1] == 1'b0)
                result = {1'b0, {WIDTH-1{1'b1}}};  // MAX_POSITIVE
            else
                result = {1'b1, {WIDTH-1{1'b0}}};  // MIN_NEGATIVE
        end else begin
            underflow = 1'b0;
            result = full_result[WIDTH-1:0];
        end
    end
endmodule

// ============================================================================
// Saturating Multiplier: For learning rate scaling
// ============================================================================
module saturating_multiplier #(
    parameter int A_WIDTH = 16,
    parameter int B_WIDTH = 8,
    parameter int RESULT_WIDTH = 16
) (
    input  logic signed [A_WIDTH-1:0]   a,
    input  logic signed [B_WIDTH-1:0]   b,
    output logic signed [RESULT_WIDTH-1:0] result,
    output logic                        overflow
);
    localparam PROD_WIDTH = A_WIDTH + B_WIDTH;
    logic signed [PROD_WIDTH-1:0] product;
    
    assign product = $signed(a) * $signed(b);
    
    always_comb begin
        // Check if result fits in RESULT_WIDTH
        if (product[PROD_WIDTH-1:RESULT_WIDTH] !== {PROD_WIDTH-RESULT_WIDTH{product[RESULT_WIDTH-1]}}) begin
            overflow = 1'b1;
            if (product[PROD_WIDTH-1] == 1'b0)
                result = {1'b0, {RESULT_WIDTH-1{1'b1}}};  // MAX_POSITIVE
            else
                result = {1'b1, {RESULT_WIDTH-1{1'b0}}};  // MIN_NEGATIVE
        end else begin
            overflow = 1'b0;
            result = product[RESULT_WIDTH-1:0];
        end
    end
endmodule

// ============================================================================
// Safe Bias Update: Combines addition with bounds checking
// ============================================================================
module safe_bias_update #(
    parameter int WIDTH = 16,
    parameter int UPDATE_BITS = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  update_en,
    input  logic signed [WIDTH-1:0]  current_bias,
    input  logic signed [UPDATE_BITS-1:0] delta,
    input  logic signed [WIDTH-1:0]  bias_max,
    input  logic signed [WIDTH-1:0]  bias_min,
    output logic signed [WIDTH-1:0]  new_bias,
    output logic                     saturated
);
    logic signed [WIDTH-1:0] delta_extended;
    logic signed [WIDTH-1:0] temp_result;
    logic add_overflow;
    logic above_max, below_min;
    
    // Sign-extend delta to full width
    assign delta_extended = {{(WIDTH-UPDATE_BITS){delta[UPDATE_BITS-1]}}, delta};
    
    // Perform saturating addition
    saturating_adder #(.WIDTH(WIDTH)) adder_inst (
        .a(current_bias),
        .b(delta_extended),
        .result(temp_result),
        .overflow(add_overflow)
    );
    
    // Check bounds
    assign above_max = (temp_result > bias_max);
    assign below_min = (temp_result < bias_min);
    
    // Apply final clamping
    always_comb begin
        if (above_max) begin
            new_bias = bias_max;
            saturated = 1'b1;
        end else if (below_min) begin
            new_bias = bias_min;
            saturated = 1'b1;
        end else begin
            new_bias = temp_result;
            saturated = add_overflow || above_max || below_min;
        end
    end
    
    // Register output on update
    logic signed [WIDTH-1:0] bias_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bias_reg <= '0;
        else if (update_en)
            bias_reg <= new_bias;
    end
    
endmodule

// ============================================================================
// Moving Average Calculator: For Q-value computation with overflow protection
// ============================================================================
module moving_average #(
    parameter int NUM_INPUTS = 5,
    parameter int DATA_WIDTH = 16,
    parameter int SHIFT_AMOUNT = 3  // Divide by 2^SHIFT_AMOUNT
) (
    input  logic signed [DATA_WIDTH-1:0] inputs [NUM_INPUTS-1:0],
    output logic signed [DATA_WIDTH-1:0] average
);
    logic signed [DATA_WIDTH+$clog2(NUM_INPUTS):0] sum;
    integer i;
    
    always_comb begin
        sum = '0;
        for (i = 0; i < NUM_INPUTS; i = i + 1)
            sum = sum + inputs[i];
        
        // Division with proper rounding
        average = (sum + (1 << (SHIFT_AMOUNT-1))) >>> SHIFT_AMOUNT;
    end
    
endmodule
