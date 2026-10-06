// ============================================================
// metadata_parser.sv
// يقرأ أول 8 بايت من ملف .bin ويفككها للـ FSM
// الترميز: raw_word = {byte7, byte6, ..., byte0}
// أي أن header_bytes[k] يقع في raw_word[8k +: 8]
// الحقول حسب contracts/metadata_format.yaml:
//   byte0      : total_layers
//   bytes1-3   : layer_weight_bytes (uint24)
//   byte4      : activation_kind
//   bytes5-6   : vector_len (uint16)
//   byte7      : reserved
// ============================================================
`timescale 1ns/1ps

import model_metadata_pkg::*;

module metadata_parser (
    input  logic                clk,
    input  logic                rst_n,
    input  logic [63:0]         raw_word,      // كلمة AXI واحدة
    input  logic                parse_en,
    output model_header_t       metadata_out,
    output logic                metadata_valid
);

    model_header_t meta_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta_reg       <= '0;
            metadata_valid <= 1'b0;
        end else if (parse_en) begin
            meta_reg.total_layers       <= raw_word[7:0];      // byte 0
            meta_reg.layer_weight_bytes <= raw_word[31:8];     // bytes 1-3
            meta_reg.activation_kind    <= raw_word[39:32];    // byte 4
            meta_reg.vector_len         <= raw_word[55:40];    // bytes 5-6
            meta_reg.reserved           <= raw_word[63:56];    // byte 7
            metadata_valid              <= 1'b1;
        end else begin
            metadata_valid <= 1'b0;
        end
    end

    assign metadata_out = meta_reg;

endmodule
