// ============================================================
// recurrent_datapath.sv
// Full recurrent loop: MUX + Layer + Loopback Register
// The datapath contains no combinational loops: every cycle passes through registers.
// Internal vector buses are flattened so that copy behavior is
// predictable and identical across all simulators.
// ============================================================
`timescale 1ns/1ps

module recurrent_datapath #(
    parameter int DATA_WIDTH = 16,
    parameter int VECTOR_LEN = 512,
    parameter int LAYER_LATENCY = 3   // simulated layer latency (cycles)
)(
    input  logic                         clk,
    input  logic                         rst_n,

    // Control from the FSM
    input  logic                         sel_external,
    input  logic                         capture_loop,
    input  logic                         start_layer,
    output logic                         layer_done,

    // External interface
    input  logic [DATA_WIDTH-1:0]        ext_data  [0:VECTOR_LEN-1],
    input  logic                         ext_valid,

    // Final output
    output logic [DATA_WIDTH-1:0]        final_data [0:VECTOR_LEN-1],
    output logic                         final_valid
);

    localparam int LAT_W  = $clog2(LAYER_LATENCY+1);
    localparam int FLAT_W = DATA_WIDTH * VECTOR_LEN;

    // ----------------------------------------------------------
    // Flattened internal signals
    // ----------------------------------------------------------
    logic [FLAT_W-1:0] ext_flat;
    logic [FLAT_W-1:0] mux_flat;
    logic              mux_valid;

    logic [FLAT_W-1:0] cap_flat;
    logic              cap_valid;

    logic [FLAT_W-1:0] loop_flat;
    logic              loop_valid;

    logic [FLAT_W-1:0] layer_flat;
    logic              layer_valid;

    // Flatten the external input element by element
    always_comb begin
        for (int i = 0; i < VECTOR_LEN; i++)
            ext_flat[i*DATA_WIDTH +: DATA_WIDTH] = ext_data[i];
    end

    // ----------------------------------------------------------
    // MUX: external vs loopback path (direct packing on flat buses)
    // ----------------------------------------------------------
    always_comb begin
        mux_flat  = sel_external ? ext_flat : loop_flat;
        mux_valid = sel_external ? ext_valid : loop_valid;
    end

    // ----------------------------------------------------------
    // Capture at layer start (operand loading into the systolic array).
    // Capturing freezes the data for the whole compute window, which
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cap_valid <= 1'b0;
            cap_flat  <= '0;
        end else begin
            cap_valid <= 1'b0;
            if (start_layer && mux_valid) begin
                cap_valid <= 1'b1;
                cap_flat  <= mux_flat;
            end
        end
    end

    // ----------------------------------------------------------
    // Layer stub — in production this is replaced by the real
    // A down-counter starts on cap_valid; settle happens at cnt==2,
    // and layer_valid is a two-cycle pulse (cnt==2 then cnt==1) covering
    // ----------------------------------------------------------
    logic [LAT_W-1:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt         <= '0;
            layer_valid <= 1'b0;
            layer_flat  <= '0;
        end else begin
            layer_valid <= 1'b0;
            if (cap_valid) begin
                cnt <= LAT_W'(LAYER_LATENCY - 1);
            end else if (cnt != '0) begin
                cnt <= cnt - 1'b1;
                if (cnt == LAT_W'(2)) begin
                    layer_flat  <= cap_flat;
                    layer_valid <= 1'b1;   // settle edge
                end else if (cnt == LAT_W'(1)) begin
                    layer_valid <= 1'b1;   // next cycle: capture-window spare
                end
            end
        end
    end

    // The done strobe is generated one cycle before the settle cycle so the FSM
    assign layer_done = (cnt == LAT_W'(1));

    // ----------------------------------------------------------
    // Loopback register: breaks the combinational path in the loop
    // (flattened implementation equivalent to loopback_register)
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loop_valid <= 1'b0;
            loop_flat  <= '0;
        end else if (capture_loop & layer_valid) begin
            loop_valid <= 1'b1;
            loop_flat  <= layer_flat;
        end
    end

    // ----------------------------------------------------------
    // Final output: valid when we are not capturing back into the loop
    // ----------------------------------------------------------
    assign final_valid = layer_valid & ~capture_loop;

    genvar gi;
    generate
        for (gi = 0; gi < VECTOR_LEN; gi++) begin : g_unflat_final
            assign final_data[gi] = layer_flat[gi*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

endmodule
