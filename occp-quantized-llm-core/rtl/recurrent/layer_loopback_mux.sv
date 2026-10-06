// ============================================================
// layer_loopback_mux.sv
// بوابة إعادة التدوير: تختار بين مدخلات خارجية ومخرجات الحلقة
// ============================================================
`timescale 1ns/1ps

module layer_loopback_mux #(
    parameter int DATA_WIDTH = 16,
    parameter int VECTOR_LEN = 512
)(
    input  logic                         sel_external,  // 1=خارجي، 0=حلقة
    input  logic [DATA_WIDTH-1:0]        ext_data  [0:VECTOR_LEN-1],
    input  logic                         ext_valid,
    input  logic [DATA_WIDTH-1:0]        loop_data [0:VECTOR_LEN-1],
    input  logic                         loop_valid,
    output logic [DATA_WIDTH-1:0]        mux_data  [0:VECTOR_LEN-1],
    output logic                         mux_valid
);

    // ملاحظة توافق (Icarus Verilog 11): النسخ العنصر-بعنصر عبر
    // always_comb مع حلقة لا يُشغَّل بشكل موثوق عند تغيّر عناصر
    // مصفوفات unpacked؛ لذلك نستخدم continuous assignments لكل عنصر.
    generate
        for (genvar gi = 0; gi < VECTOR_LEN; gi++) begin : g_mux
            assign mux_data[gi] = sel_external ? ext_data[gi] : loop_data[gi];
        end
    endgenerate

    assign mux_valid = sel_external ? ext_valid : loop_valid;

endmodule
