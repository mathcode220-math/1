// ============================================================
// model_metadata_pkg.sv
// حزمة الأنواع المشتركة بين جميع الوحدات
// ============================================================
`ifndef MODEL_METADATA_PKG_SV
`define MODEL_METADATA_PKG_SV

package model_metadata_pkg;

    // ------------------------------------------------------------
    // أنواع التنشيط
    // ------------------------------------------------------------
    typedef enum logic [2:0] {
        ACT_RELU    = 3'b000,
        ACT_GELU    = 3'b001,
        ACT_SILU    = 3'b010,
        ACT_TANH    = 3'b011,
        ACT_SOFTMAX = 3'b100
    } activation_t;

    // ------------------------------------------------------------
    // رأس النموذج (8 بايت = كلمة AXI واحدة)
    // الحقول مخزنة MSB-first كما لو كان الرأس مصفوفة البايتات
    // header_bytes[0..7] ممدودة إلى 64 بت: raw_word = {b7,b6,...,b0}
    // أي أن byte k يقع في raw_word[8k +: 8] (little-endian على مستوى الكلمة)
    // مطابقة لـ contracts/metadata_format.yaml:
    //   byte0=total_layers | bytes1-3=layer_weight_bytes | byte4=activation_kind
    //   bytes5-6=vector_len | byte7=reserved
    // ------------------------------------------------------------
    typedef struct packed {
        logic [7:0]   reserved;          // byte 7 (MSB)
        logic [15:0]  vector_len;        // bytes 6-5
        logic [7:0]   activation_kind;   // byte 4 (يُقرأ عبر دالة to_activation)
        logic [23:0]  layer_weight_bytes;// bytes 3-1
        logic [7:0]   total_layers;      // byte 0 (LSB)
    } model_header_t;

    // ------------------------------------------------------------
    // تحويل آمن إلى نوع التنشيط (أي قيمة غير معروفة => RELU)
    // ------------------------------------------------------------
    function automatic activation_t to_activation(logic [7:0] kind);
        case (kind)
            8'd0:    to_activation = ACT_RELU;
            8'd1:    to_activation = ACT_GELU;
            8'd2:    to_activation = ACT_SILU;
            8'd3:    to_activation = ACT_TANH;
            8'd4:    to_activation = ACT_SOFTMAX;
            default: to_activation = ACT_RELU;
        endcase
    endfunction

    // ------------------------------------------------------------
    // حالات الـ FSM
    // ------------------------------------------------------------
    typedef enum logic [3:0] {
        S_IDLE          = 4'b0000,
        S_LOAD_META     = 4'b0001,
        S_PREFETCH_W    = 4'b0010,
        S_LOAD_LAYER_0  = 4'b0011,
        S_COMPUTE       = 4'b0100,
        S_WAIT_DONE     = 4'b0101,
        S_LOOP_CHECK    = 4'b0110,
        S_OUTPUT_TOKEN  = 4'b0111,
        S_ERROR         = 4'b1000
    } fsm_state_t;

endpackage : model_metadata_pkg

`endif
