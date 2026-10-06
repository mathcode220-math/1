// ============================================================
// layer_loopback_mux.sv
// Recycle gate: selects between external inputs and loopback outputs.
// Purely combinational; the sequential break lives in loopback_register.
// ============================================================
`timescale 1ns/1ps

module layer_loopback_mux #(
    parameter int DATA_WIDTH = 16,
    parameter int VECTOR_LEN = 512
)(
    input  logic                         sel_external,  // 1 = external, 0 = loopback
    input  logic [DATA_WIDTH-1:0]        ext_data  [0:VECTOR_LEN-1],
    input  logic                         ext_valid,
    input  logic [DATA_WIDTH-1:0]        loop_data [0:VECTOR_LEN-1],
    input  logic                         loop_valid,
    output logic [DATA_WIDTH-1:0]        mux_data  [0:VECTOR_LEN-1],
    output logic                         mux_valid
);

    always_comb begin
        if (sel_external) begin
            mux_data  = ext_data;
            mux_valid = ext_valid;
        end else begin
            mux_data  = loop_data;
            mux_valid = loop_valid;
        end
    end

endmodule
