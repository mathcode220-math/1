// ============================================================
// layer_loopback_mux.sv
// بوابة إعادة التدوير: تختار بين مدخلات خارجية ومخرجات الحلقة.
// ملاحظة تنفيذية: النسخ يتم عنصرًا بعنصر عبر مصفوفة وسيطة
// لتجنب مشاركة مراجع المصفوفات في بعض المحاكيات (Icarus Verilog)
// التي قد تُنشئ حلقة محاكاة عند نسخ المصفوفات بالكامل.
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

    logic [DATA_WIDTH-1:0] tmp [0:VECTOR_LEN-1];

    always_comb begin
        if (sel_external) begin
            for (int i = 0; i < VECTOR_LEN; i++) tmp[i] = ext_data[i];
            mux_valid = ext_valid;
        end else begin
            for (int i = 0; i < VECTOR_LEN; i++) tmp[i] = loop_data[i];
            mux_valid = loop_valid;
        end
    end

    always_comb begin
        for (int i = 0; i < VECTOR_LEN; i++) mux_data[i] = tmp[i];
    end

endmodule
