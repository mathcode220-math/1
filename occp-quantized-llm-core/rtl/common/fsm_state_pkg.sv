// ============================================================
// fsm_state_pkg.sv
// Canonical FSM state encodings shared between RTL and testbenches.
// Values match occp_pipeline_fsm.sv and contracts/recurrent_interfaces.yaml.
// ============================================================
`ifndef FSM_STATE_PKG_SV
`define FSM_STATE_PKG_SV

`timescale 1ns/1ps

package fsm_state_pkg;

    localparam logic [3:0] S_IDLE          = 4'd0;
    localparam logic [3:0] S_LOAD_META     = 4'd1;
    localparam logic [3:0] S_PREFETCH_W    = 4'd2;
    localparam logic [3:0] S_LOAD_LAYER_0  = 4'd3;
    localparam logic [3:0] S_COMPUTE       = 4'd4;
    localparam logic [3:0] S_WAIT_DONE     = 4'd5;
    localparam logic [3:0] S_LOOP_CHECK    = 4'd6;
    localparam logic [3:0] S_OUTPUT_TOKEN  = 4'd7;
    localparam logic [3:0] S_ERROR         = 4'd8;

endpackage : fsm_state_pkg

`endif
