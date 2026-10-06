// ============================================================
// metadata_parser.sv
// يقرأ أول 8 بايت من ملف .bin ويفككها للـ FSM
// التوزيع مطابق لـ contracts/metadata_format.yaml (little-endian):
//   [7:0]    total_layers      (byte 0)
//   [31:8]   layer_weight_bytes(bytes 1-3, uint24)
//   [34:32]  activation_kind   (bits 2:0 من byte 4)
//   [50:35]  vector_len        (bytes 5-6, uint16)
//   [63:51]  reserved          (bit 35 من byte 4 + byte 7)
// ============================================================
`timescale 1ns/1ps

module metadata_parser #(
    parameter int HEADER_BITS = 64
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic [HEADER_BITS-1:0]       raw_word,      // كلمة AXI واحدة little-endian
    input  logic                         parse_en,
    output logic [HEADER_BITS-1:0]       metadata_out,  // model_header_t مسطّح (FSM unpacks)
    output logic                         metadata_valid
);

    logic [HEADER_BITS-1:0] meta_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta_reg       <= '0;
            metadata_valid <= 1'b0;
        end else if (parse_en) begin
            // رأس النموذج مطابق تماماً لكلمة AXI little-endian
            meta_reg       <= raw_word;
            metadata_valid <= 1'b1;
        end else begin
            metadata_valid <= 1'b0;
        end
    end

    assign metadata_out = meta_reg;

endmodule
