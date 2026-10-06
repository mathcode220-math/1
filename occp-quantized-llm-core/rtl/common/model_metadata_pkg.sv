// ============================================================
// model_metadata_pkg.sv
// Shared type definitions used across all OCCP modules.
// Fields match contracts/metadata_format.yaml (8-byte little-endian header).
// NOTE: the header is defined as a flat byte array instead of a packed
// struct because Icarus Verilog 11 fails to elaborate "pkg::type" references
// outside the importing module (crash in elab_type.cc).
// All project code and comments are written in English.
// ============================================================
`ifndef MODEL_METADATA_PKG_SV
`define MODEL_METADATA_PKG_SV

`timescale 1ns/1ps

package model_metadata_pkg;

    // ------------------------------------------------------------
    // Activation kinds (localparams instead of enums for simulator
    // compatibility)
    // ------------------------------------------------------------
    localparam logic [2:0] ACT_RELU    = 3'b000;
    localparam logic [2:0] ACT_GELU    = 3'b001;
    localparam logic [2:0] ACT_SILU    = 3'b010;
    localparam logic [2:0] ACT_TANH    = 3'b011;
    localparam logic [2:0] ACT_SOFTMAX = 3'b100;

    localparam int HEADER_BYTES = 8;   // 8 bytes = one AXI4-Lite word

    // ------------------------------------------------------------
    // Model header: 8-byte little-endian layout:
    //   [0]     total_layers        uint8
    //   [1..3]  layer_weight_bytes  uint24
    //   [4]     activation_kind     bits[2:0]
    //   [5..6]  vector_len          uint16
    //   [7]     reserved            must be zero
    // ------------------------------------------------------------
    typedef logic [7:0] model_header_t [0:HEADER_BYTES-1];

endpackage : model_metadata_pkg

`endif
