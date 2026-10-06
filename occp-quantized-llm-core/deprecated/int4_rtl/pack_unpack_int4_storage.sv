//=============================================================================
// pack_unpack_int4  (file: pack_unpack_int4_storage.sv)
// INT4 STORAGE, INT8 COMPUTE: sign-extends packed INT4 nibbles to INT8
// before the 8-bit systolic array. There is no 4-bit MAC.
//=============================================================================

`ifndef SYNTHESIS
`timescale 1ns/1ps
`endif

module pack_unpack_int4 (
    input  logic [3:0]        nibble,
    output logic signed [7:0] ext8
);
    assign ext8 = {{4{nibble[3]}}, nibble};
endmodule

module unpack_int4_vec #(
    parameter N = 4
)(
    input  logic [N-1:0][3:0] nibbles,
    output logic signed [N-1:0][7:0] bytes
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g
            pack_unpack_int4 u (
                .nibble (nibbles[i]),
                .ext8   (bytes[i])
            );
        end
    endgenerate
endmodule
