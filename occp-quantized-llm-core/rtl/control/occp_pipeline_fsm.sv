// ============================================================
// occp_pipeline_fsm.sv — Fixed version (E-1, E-2, E-3, E-4, E-5, E-7)
// State chain:
//   IDLE -> LOAD_META -> PREFETCH_W -> LOAD_LAYER_0 -> COMPUTE
//        -> WAIT_DONE  -> LOOP_CHECK -> (PREFETCH_W | OUTPUT_TOKEN) -> IDLE
// Fixes:
//   E-1: running_count increments at the layer_done && softmax_done edge
//        in WAIT_DONE (not inside COMPUTE), so the is_last_layer decision
//        is taken only after the count has completed.
//   E-2: S_LOAD_LAYER_0 is a live state on the mandatory path (from PREFETCH_W).
//   E-3: WAIT_DONE requires layer_done && softmax_done together (per contract).
//   E-4: buf_sel computed with continuous assigns outside always_comb.
//   E-5: registered token_pulse — output_token_valid is a safe one-cycle pulse.
//   E-7: full reset of counters/registers on new-token start and in ERROR.
// Compatibility note: metadata_in is a flat 64-bit little-endian word matching
// the 8-byte header in contracts/metadata_format.yaml (byte0 = total_layers).
// State encodings match the contract in rtl/common/fsm_state_pkg.sv.
// All project code and comments are written in English.
// ============================================================
`timescale 1ns/1ps

module occp_pipeline_fsm #(
    parameter int MAX_LAYERS = 128
)(
    input  logic                clk,
    input  logic                rst_n,

    // From the host
    input  logic                host_start,

    // From metadata_parser
    input  logic [63:0]         metadata_in,     // 8-byte little-endian header
    input  logic                metadata_valid,

    // From recurrent_datapath / sa_done_generator
    input  logic                layer_done,

    // From the softmax unit
    input  logic                softmax_done,

    // From the weight subsystem (weight_pingpong load_done)
    input  logic                weight_ready,

    // To the datapath
    output logic                sel_external,
    output logic                capture_loop,
    output logic                start_layer,

    // To the weight subsystem
    output logic                buf_sel,
    output logic                weight_load_en,
    output logic [7:0]          weight_layer_idx,

    // To the external interface
    output logic                output_token_valid,
    output logic                pipeline_busy,
    output logic [7:0]          layer_counter_out,

    // FSM state for observation
    output logic [3:0]          state_out
);

    // ----------------------------------------------------------
    // State encodings (match contract fsm_state_pkg)
    // ----------------------------------------------------------
    localparam logic [3:0] S_IDLE         = 4'd0;
    localparam logic [3:0] S_LOAD_META    = 4'd1;
    localparam logic [3:0] S_PREFETCH_W   = 4'd2;
    localparam logic [3:0] S_LOAD_LAYER_0 = 4'd3;
    localparam logic [3:0] S_COMPUTE      = 4'd4;
    localparam logic [3:0] S_WAIT_DONE    = 4'd5;
    localparam logic [3:0] S_LOOP_CHECK   = 4'd6;
    localparam logic [3:0] S_OUTPUT_TOKEN = 4'd7;
    localparam logic [3:0] S_ERROR        = 4'd8;

    logic [3:0] state, next_state;

    logic [7:0] total_layers_reg;
    logic [7:0] running_count;      // number of completed layers
    logic       token_pulse;        // E-5: registered one-cycle token pulse

    // ----------------------------------------------------------
    // E-4: derived signals computed outside always_comb via assigns
    // running_count = number of completed layers, so the layer currently
    // in progress is numbered running_count+1
    // ----------------------------------------------------------
    logic       current_is_last;
    logic       has_next_layer;
    logic       is_last_layer;

    logic [7:0] next_layer_num;
    logic       buf_sel_bit;
    logic       done_edge;         // edge leaving WAIT_DONE with a full done strobe

    assign next_layer_num  = running_count + 8'd1;
    assign buf_sel_bit     = next_layer_num[0];
    assign buf_sel         = buf_sel_bit;              // bank of the layer in progress
    // E-1: current layer completes only when both strobes share one edge
    assign done_edge       = layer_done && softmax_done;
    assign current_is_last = (next_layer_num >= total_layers_reg) &&
                             (total_layers_reg != 8'd0);
    assign has_next_layer  = next_layer_num < total_layers_reg;
    // E-1: in LOOP_CHECK running_count has already been incremented —
    //      the last-layer decision is taken after the increment
    assign is_last_layer   = (running_count >= total_layers_reg) &&
                             (total_layers_reg != 8'd0);

    // ----------------------------------------------------------
    // 1) Next-state logic
    // ----------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (host_start && metadata_valid)
                    next_state = S_LOAD_META;
            end
            S_LOAD_META:                          next_state = S_PREFETCH_W;
            S_PREFETCH_W:   if (weight_ready)     next_state = S_LOAD_LAYER_0;
            S_LOAD_LAYER_0:                       next_state = S_COMPUTE;   // E-2 live state
            S_COMPUTE:                            next_state = S_WAIT_DONE;
            S_WAIT_DONE: begin                    // E-3: both strobes required
                if (done_edge)                    next_state = S_LOOP_CHECK;
            end
            S_LOOP_CHECK: begin                   // E-1: decision after count completes
                // Hold for exactly one full cycle so the host/TB observes the
                // decision state, then depart on the next edge.
                if (loop_hold) begin
                    if (is_last_layer)            next_state = S_OUTPUT_TOKEN;
                    else                          next_state = S_PREFETCH_W;
                end
            end
            S_OUTPUT_TOKEN: begin
                // One-cycle token pulse, then back to IDLE. The host must
                // re-arm with host_start && metadata_valid for the next token.
                next_state = S_IDLE;                                        // E-5/E-7
            end
            S_ERROR:                              next_state = S_IDLE;
            default:                              next_state = S_ERROR;
        endcase
    end

    // ----------------------------------------------------------
    // 2) State register + metadata capture (single edge, no stall).
    //    Capture is compared against next_state because the registered
    //    state advances on the same edge that first shows LOAD_META.
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            total_layers_reg <= 8'd0;
        end else begin
            state <= next_state;
            if ((next_state == S_LOAD_META) && metadata_valid)
                total_layers_reg <= metadata_in[7:0];   // byte0 = total_layers
            if (state == S_ERROR)
                total_layers_reg <= 8'd0;               // E-7 full clear
        end
    end

    // ----------------------------------------------------------
    // 3) E-1: counter increments at the layer_done && softmax_done edge
    //    in S_WAIT_DONE — not inside S_COMPUTE.
    //    Priority: new-token reset > done increment > OUTPUT/ERROR clear.
    // ----------------------------------------------------------
    logic start_new_token;   // edge entering LOAD_META with a valid header

    assign start_new_token = (next_state == S_LOAD_META) && metadata_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_count <= 8'd0;
        end else if (start_new_token) begin
            running_count <= 8'd0;                                   // E-7 new token start
        end else if ((state == S_WAIT_DONE) && done_edge) begin
            running_count <= running_count + 8'd1;                   // core fix (E-1)
        end else if (((state == S_OUTPUT_TOKEN) && (next_state == S_IDLE))
                     || (state == S_ERROR)) begin
            running_count <= 8'd0;                       // E-7: clear after token shown
        end
    end

    // ----------------------------------------------------------
    // 4) E-5: token_pulse — safe single-cycle registered issue.
    //    The register is loaded on the same edge that latches
    //    state = S_OUTPUT_TOKEN, so it is HIGH during exactly the first
    //    (and only) OUTPUT_TOKEN cycle, then clears by default.
    // ----------------------------------------------------------
    logic loop_hold;   // one-cycle hold inside S_LOOP_CHECK

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)             loop_hold <= 1'b0;
        else if (done_edge)     loop_hold <= 1'b1;   // armed leaving WAIT_DONE
        else if (state == S_LOOP_CHECK)
                                loop_hold <= 1'b0;   // consumed after one cycle
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            token_pulse <= 1'b0;
        else
            // Loaded on the same edge that latches state = OUTPUT_TOKEN, so
            // the pulse is HIGH during exactly that one cycle (OUTPUT_TOKEN
            // always exits to IDLE next).
            token_pulse <= (next_state == S_OUTPUT_TOKEN);
    end

    // ----------------------------------------------------------
    // 5) Combinational output logic
    // ----------------------------------------------------------
    always_comb begin
        sel_external       = 1'b0;
        capture_loop       = 1'b0;
        start_layer        = 1'b0;
        weight_load_en     = 1'b0;
        weight_layer_idx   = 8'd0;
        output_token_valid = 1'b0;
        pipeline_busy      = (state != S_IDLE);
        state_out          = state;

        case (state)
            S_IDLE: begin
                sel_external = 1'b1;
            end

            S_LOAD_META: begin
                // no outputs — header capture only
            end

            S_PREFETCH_W: begin
                weight_load_en   = 1'b1;
                weight_layer_idx = running_count + 8'd1;   // load weights of current layer
            end

            S_LOAD_LAYER_0: begin                          // E-2: live state
                sel_external   = (running_count == 8'd0);  // first layer from outside
                weight_load_en = has_next_layer;           // prefetch next layer
                if (has_next_layer)
                    weight_layer_idx = running_count + 8'd2;
            end

            S_COMPUTE: begin
                start_layer      = 1'b1;
                sel_external     = (running_count == 8'd0);
                capture_loop     = !current_is_last;       // no capture after last layer
                weight_load_en   = has_next_layer;
                if (has_next_layer)
                    weight_layer_idx = running_count + 8'd2;
            end

            S_WAIT_DONE: begin
                capture_loop = !current_is_last;
            end

            S_LOOP_CHECK: begin
                // capture current-layer result before moving to the next compute
                capture_loop = !is_last_layer;
            end

            S_OUTPUT_TOKEN: begin
                output_token_valid = token_pulse;          // E-5: safe one-cycle pulse
            end

            S_ERROR: begin
                // all outputs low except busy
            end

            default: ;
        endcase
    end

    // Display: actual number of completed layers
    assign layer_counter_out = running_count;

endmodule
