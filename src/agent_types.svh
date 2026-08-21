//============================================================================
//  SILICON AGENT: Type Definitions and Parameters
//  Centralized type definitions for consistent usage across all modules
//============================================================================

`ifndef AGENT_TYPES_SVH
`define AGENT_TYPES_SVH

// ============================================================================
// Default Parameters (can be overridden during instantiation)
// ============================================================================
`ifndef NUM_TOKENS
    `define NUM_TOKENS_DEFAULT 5
`else
    `define NUM_TOKENS_DEFAULT `NUM_TOKENS
`endif

`ifndef DATA_WIDTH
    `define DATA_WIDTH_DEFAULT 16
`else
    `define DATA_WIDTH_DEFAULT `DATA_WIDTH
`endif

`ifndef BIAS_WIDTH
    `define BIAS_WIDTH_DEFAULT 16
`else
    `define BIAS_WIDTH_DEFAULT `BIAS_WIDTH
`endif

`ifndef EVIDENCE_WIDTH
    `define EVIDENCE_WIDTH_DEFAULT 16
`else
    `define EVIDENCE_WIDTH_DEFAULT `EVIDENCE_WIDTH
`endif

`ifndef REWARD_WIDTH
    `define REWARD_WIDTH_DEFAULT 8
`else
    `define REWARD_WIDTH_DEFAULT `REWARD_WIDTH
`endif

`ifndef LEARNING_RATE
    `define LEARNING_RATE_DEFAULT 8'd16  // 0.1 in Q8.8 format
`else
    `define LEARNING_RATE_DEFAULT `LEARNING_RATE
`endif

`ifndef Q_ALPHA_SHIFT
    `define Q_ALPHA_SHIFT_DEFAULT 3  // 1/8 = >>3 for EMA
`else
    `define Q_ALPHA_SHIFT_DEFAULT `Q_ALPHA_SHIFT
`endif

`ifndef BITSTREAM_LEN
    `define BITSTREAM_LEN_DEFAULT 256
`else
    `define BITSTREAM_LEN_DEFAULT `BITSTREAM_LEN
`endif

`ifndef DIM
    `define DIM_DEFAULT 8
`else
    `define DIM_DEFAULT `DIM
`endif

// ============================================================================
// Bias Limits for Saturation Protection
// ============================================================================
`define BIAS_MAX(width)   {(width){1'b0}} - 1  // 2^(width-1) - 1
`define BIAS_MIN(width)   {(width){1'b1}}      // -2^(width-1)

// ============================================================================
// FSM State Enumerations
// ============================================================================
typedef enum logic [2:0] {
    AGENT_ST_IDLE      = 3'b000,
    AGENT_ST_SAMPLE    = 3'b001,
    AGENT_ST_COMPUTE_Q = 3'b010,
    AGENT_ST_UPDATE    = 3'b011,
    AGENT_ST_CONVERGED = 3'b100,
    AGENT_ST_ERROR     = 3'b111
} agent_state_e;

typedef enum logic [1:0] {
    CDC_ST_IDLE   = 2'b00,
    CDC_ST_REQ    = 2'b01,
    CDC_ST_ACK    = 2'b10,
    CDC_ST_DONE   = 2'b11
} cdc_state_e;

// ============================================================================
// Configuration Register Structure
// ============================================================================
typedef struct packed {
    logic [7:0]  learning_rate;
    logic [2:0]  q_alpha_shift;
    logic [15:0] bias_max;
    logic [15:0] bias_min;
    logic [7:0]  target_reward;
    logic        enable_learning;
    logic        reset_q_values;
    logic [3:0]  reserved;
} agent_config_t;

// ============================================================================
// Performance Counters Structure
// ============================================================================
typedef struct packed {
    logic [31:0] total_cycles;
    logic [31:0] total_updates;
    logic [31:0] winner_counts [`NUM_TOKENS_DEFAULT-1:0];
    logic [15:0] final_bias [`NUM_TOKENS_DEFAULT-1:0];
    logic [15:0] final_q [`NUM_TOKENS_DEFAULT-1:0];
    logic        converged;
    logic [31:0] cycles_to_converge;
} perf_counters_t;

// ============================================================================
// Reset Strategy Definition
// ============================================================================
// All resets are: asynchronous, active-low (rst_n)
// Synchronous release is recommended for CDC safety

`endif // AGENT_TYPES_SVH
