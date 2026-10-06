// ============================================================
// occp_pipeline_fsm.sv
// آلة الحالات المسؤولة عن تشغيل خط المعالجة العودي الكامل:
//   IDLE -> LOAD_META -> PREFETCH_W -> LOAD_LAYER_0 -> COMPUTE
//        -> WAIT_DONE  -> LOOP_CHECK -> (PREFETCH_W | OUTPUT_TOKEN)
// المدخلات/المخرجات مطابقة للعقد في contracts/recurrent_interfaces.yaml
// ملاحظة: metadata_in كلمة 64-bit مسطّحة little-endian مطابقة
// لـ model_header_t في الحزمة (byte0 = total_layers).
// ============================================================
`timescale 1ns/1ps

module occp_pipeline_fsm #(
    parameter int MAX_LAYERS = 128
)(
    input  logic                clk,
    input  logic                rst_n,

    // من المضيف
    input  logic                host_start,

    // من metadata_parser
    input  logic [63:0]         metadata_in,     // رأس 8 بايت little-endian
    input  logic                metadata_valid,

    // من recurrent_datapath
    input  logic                layer_done,

    // من softmax_unit
    input  logic                softmax_done,

    // من weight_pingpong (load_done)
    input  logic                weight_ready,

    // إلى datapath
    output logic                sel_external,
    output logic                capture_loop,
    output logic                start_layer,

    // إلى نظام الأوزان
    output logic                buf_sel,
    output logic                weight_load_en,
    output logic [7:0]          weight_layer_idx,

    // إلى الواجهة الخارجية
    output logic                output_token_valid,
    output logic                pipeline_busy,
    output logic [7:0]          layer_counter_out,

    // حالة الآلة للمراقبة
    output logic [3:0]          state_out
);

    // أكواد الحالات مطابقة لـ rtl/common/fsm_state_pkg.sv
    localparam logic [3:0] S_IDLE         = 4'd0;
    localparam logic [3:0] S_LOAD_META    = 4'd1;
    localparam logic [3:0] S_PREFETCH_W   = 4'd2;
    localparam logic [3:0] S_LOAD_LAYER_0 = 4'd3;
    localparam logic [3:0] S_COMPUTE      = 4'd4;
    localparam logic [3:0] S_WAIT_DONE    = 4'd5;
    localparam logic [3:0] S_LOOP_CHECK   = 4'd6;
    localparam logic [3:0] S_OUTPUT_TOKEN = 4'd7;
    localparam logic [3:0] S_ERROR        = 4'd8;

    logic [3:0] state, next_state;

    logic [7:0] total_layers_reg;
    logic [7:0] running_count;    // عدد الطبقات المكتملة (سجل حقيقي)
    logic       started;          // تم بدء التوكن الحالي
    logic [7:0] layer_count;      // نسخة توافقية للعرض والتوجيه
    logic       is_last_layer;

    // ----------------------------------------------------------
    // عدّاد الطبقات المسجل: يتقدم على الحافة التي تلي نبضة
    // start_layer (نهاية دورة COMPUTE).
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_count <= 8'd0;
            started       <= 1'b0;
        end else if ((state == S_IDLE) && host_start) begin
            running_count <= 8'd0;               // تصفير عند بداية توكن جديد
            started       <= 1'b0;
        end else begin
            if (start_layer) started <= 1'b1;
            if (state == S_COMPUTE) begin
                running_count <= running_count + 8'd1;
            end
        end
    end

    // نسخة توافقية: أثناء COMPUTE تكون الطبقة الجارية قد بدأت للتو
    always_comb begin
        if (state == S_COMPUTE) layer_count = running_count + 8'd1;
        else                    layer_count = running_count;
    end

    assign layer_counter_out = layer_count;

    // الطبقة الجارية هي الأخيرة إذا كان رقمها = total_layers
    assign is_last_layer = (layer_count >= total_layers_reg) && started;

    // ----------------------------------------------------------
    // سجل الحالة + التقاط Metadata أثناء S_LOAD_META
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            total_layers_reg <= 8'd0;
        end else begin
            state <= next_state;
            if ((state == S_LOAD_META) && metadata_valid) begin
                total_layers_reg <= metadata_in[7:0];   // byte 0 = total_layers
            end
        end
    end

    // ----------------------------------------------------------
    // منطق الحالة التالي
    // ----------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:         if (host_start) next_state = S_LOAD_META;
            S_LOAD_META:    if (metadata_valid) next_state = S_PREFETCH_W;
            S_PREFETCH_W:   if (weight_ready)   next_state = S_COMPUTE;
            S_COMPUTE:                          next_state = S_WAIT_DONE;
            S_WAIT_DONE:    if (layer_done)     next_state = S_LOOP_CHECK;
            S_LOOP_CHECK: begin
                if (is_last_layer)              next_state = S_OUTPUT_TOKEN;
                else                            next_state = S_PREFETCH_W; // شحن أوزان الطبقة التالية
            end
            S_OUTPUT_TOKEN: if (softmax_done)   next_state = S_IDLE;
            S_ERROR:                            next_state = S_IDLE;
            default:                            next_state = S_ERROR;
        endcase
    end

    // ----------------------------------------------------------
    // إشارات التحكم — نبضة start_layer أحادية الدورة في S_COMPUTE
    // ----------------------------------------------------------
    always_comb begin
        sel_external       = (state == S_COMPUTE) && (layer_count == 8'd1);
        capture_loop       = (state == S_WAIT_DONE) && !is_last_layer;
        start_layer        = (state == S_COMPUTE);
        weight_load_en     = (state == S_PREFETCH_W);
        buf_sel            = layer_count[0];
        weight_layer_idx   = layer_count;
        output_token_valid = (state == S_OUTPUT_TOKEN) && softmax_done;
        pipeline_busy      = (state != S_IDLE);
        state_out          = state;
    end

endmodule
