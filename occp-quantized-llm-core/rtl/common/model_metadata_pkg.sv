// ============================================================
// model_metadata_pkg.sv
// حزمة الأنواع المشتركة بين جميع الوحدات
// الحقول مطابقة لـ contracts/metadata_format.yaml (رأس 8 بايت little-endian)
// ملاحظة: تم تعريف الرأس كمصفوفة بايتات بدلاً من struct packed
// لأن Icarus Verilog 11 يفشل في elaboration عند استخدام
// "pkg::type" خارج الوحدة المستورِدة (crash في elab_type.cc).
// ============================================================
`ifndef MODEL_METADATA_PKG_SV
`define MODEL_METADATA_PKG_SV

`timescale 1ns/1ps

package model_metadata_pkg;

    // ------------------------------------------------------------
    // أنواع التنشيط (ثوابت بدل enum لتوافق أدوات المحاكاة)
    // ------------------------------------------------------------
    localparam logic [2:0] ACT_RELU    = 3'b000;
    localparam logic [2:0] ACT_GELU    = 3'b001;
    localparam logic [2:0] ACT_SILU    = 3'b010;
    localparam logic [2:0] ACT_TANH    = 3'b011;
    localparam logic [2:0] ACT_SOFTMAX = 3'b100;

    localparam int HEADER_BYTES = 8;   // 8 بايت = كلمة AXI واحدة

    // ------------------------------------------------------------
    // رأس النموذج: مصفوفة 8 بايتات little-endian مطابقة للياقة:
    //   [0]   total_layers      uint8
    //   [1..3] layer_weight_bytes uint24
    //   [4]   activation_kind   bits[2:0]
    //   [5..6] vector_len       uint16
    //   [7]   reserved          يجب أن يكون صفراً
    // ------------------------------------------------------------
    typedef logic [7:0] model_header_t [0:HEADER_BYTES-1];

endpackage : model_metadata_pkg

`endif
