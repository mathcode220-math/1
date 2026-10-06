// ============================================================
// fsm_state_pkg.sv
// حالات آلة خط المعالجة — معرّفة كحزمة منفصلة لضمان توافق
// المحاكيات، ومطابقة للعقد في contracts/recurrent_interfaces.yaml
// ============================================================
`ifndef FSM_STATE_PKG_SV
`define FSM_STATE_PKG_SV

`timescale 1ns/1ps

package fsm_state_pkg;

    localparam logic [3:0] S_IDLE          = 4'b0000;
    localparam logic [3:0] S_LOAD_META     = 4'b0001;
    localparam logic [3:0] S_PREFETCH_W    = 4'b0010;
    localparam logic [3:0] S_LOAD_LAYER_0  = 4'b0011;
    localparam logic [3:0] S_COMPUTE       = 4'b0100;
    localparam logic [3:0] S_WAIT_DONE     = 4'b0101;
    localparam logic [3:0] S_LOOP_CHECK    = 4'b0110;
    localparam logic [3:0] S_OUTPUT_TOKEN  = 4'b0111;
    localparam logic [3:0] S_ERROR         = 4'b1000;

endpackage : fsm_state_pkg

`endif
