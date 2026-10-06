// ============================================================
// occp_pipeline_fsm.sv — النسخة المُصلَحة (E-1, E-2, E-3, E-4, E-5, E-7)
// خط الحالة:
//   IDLE -> LOAD_META -> PREFETCH_W -> LOAD_LAYER_0 -> COMPUTE
//        -> WAIT_DONE  -> LOOP_CHECK -> (PREFETCH_W | OUTPUT_TOKEN) -> IDLE
// الإصلاحات:
//   E-1: running_count يزيد لحظة layer_done && softmax_done في WAIT_DONE
//        وليس داخل COMPUTE، لذا يُتخذ قرار is_last_layer بعد اكتمال العدّ.
//   E-2: S_LOAD_LAYER_0 حالة حية في المسار الإلزامي (من PREFETCH_W).
//   E-3: WAIT_DONE يشترط layer_done && softmax_done معاً (حسب العقد).
//   E-4: buf_sel محسوب بـ assign خارج كتلة always_comb.
//   E-5: token_pulse مسجّل — output_token_valid نبضة آمنة دورة واحدة.
//   E-7: تصفير كامل للعدّاد والنواقل عند IDLE / ERROR.
// ملاحظة توافق: metadata_in كلمة 64-bit مسطّحة little-endian مطابقة
// لرأس 8 بايت في contracts/metadata_format.yaml (byte0 = total_layers).
// أكواد الحالات مطابقة للعقد في rtl/common/fsm_state_pkg.sv.
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

    // من recurrent_datapath / sa_done_generator
    input  logic                layer_done,

    // من softmax_unit
    input  logic                softmax_done,

    // من نظام الأوزان (weight_pingpong load_done)
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

    // ----------------------------------------------------------
    // أكواد الحالات (مطابقة للعقد fsm_state_pkg)
    // ----------------------------------------------------------
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
    logic [7:0] running_count;      // عدد الطبقات المكتملة
    logic       token_pending;      // الطبقة الأخيرة اكتملت بانتظار إصدار التوكن
    logic       token_pulse;        // E-5: نبضة التوكن المسجلة

    // ----------------------------------------------------------
    // E-4: المشتقات المحسوبة خارج always_comb عبر assign
    // running_count = عدد الطبقات المكتملة، فالطبقة الجارية رقمها running_count+1
    // ----------------------------------------------------------
    logic       current_is_last;
    logic       has_next_layer;
    logic       is_last_layer;

    logic [7:0] next_layer_num;
    logic       buf_sel_bit;
    logic       done_edge;         // حافة مغادرة WAIT_DONE بإشارة Done كاملة

    assign next_layer_num  = running_count + 8'd1;
    assign buf_sel_bit     = next_layer_num[0];
    assign buf_sel         = buf_sel_bit;              // بنك الطبقة الجارية
    // E-1: إتمام الطبقة الجارية = الاثنتان معاً على حافة واحدة
    assign done_edge       = layer_done && softmax_done;
    assign current_is_last = (next_layer_num >= total_layers_reg) &&
                             (total_layers_reg != 8'd0);
    assign has_next_layer  = next_layer_num < total_layers_reg;
    // E-1: في LOOP_CHECK يكون running_count قد اكتمل — القرار بعد الزيادة
    assign is_last_layer   = (running_count >= total_layers_reg) &&
                             (total_layers_reg != 8'd0);

    // ----------------------------------------------------------
    // 1) منطق الانتقال
    // ----------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (host_start && metadata_valid)
                    next_state = S_LOAD_META;
            end
            S_LOAD_META:                          next_state = S_PREFETCH_W;
            S_PREFETCH_W:   if (weight_ready)     next_state = S_LOAD_LAYER_0;
            S_LOAD_LAYER_0:                       next_state = S_COMPUTE;   // E-2 حية
            S_COMPUTE:                            next_state = S_WAIT_DONE;
            S_WAIT_DONE: begin                    // E-3: الاثنتان معاً
                if (done_edge)                    next_state = S_LOOP_CHECK;
            end
            S_LOOP_CHECK: begin                   // E-1: القرار بعد اكتمال العدّ
                if (is_last_layer)                next_state = S_OUTPUT_TOKEN;
                else                              next_state = S_PREFETCH_W;
            end
            S_OUTPUT_TOKEN: begin
                if (!token_pending)               next_state = S_IDLE;      // E-5/E-7
                else                              next_state = S_LOAD_META; // توكن تلقائي (AR)
            end
            S_ERROR:                              next_state = S_IDLE;
            default:                              next_state = S_ERROR;
        endcase
    end

    // ----------------------------------------------------------
    // 2) سجل الحالة + التقاط Metadata (حافة واحدة، بدون تأجيل)
    //    الالتقاط يُقارَن بـ next_state لأن state المسجل يتقدم
    //    في نفس الحافة التي يظهر فيها LOAD_META كقيمة جديدة.
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            total_layers_reg <= 8'd0;
        end else begin
            state <= next_state;
            if ((next_state == S_LOAD_META) && metadata_valid)
                total_layers_reg <= metadata_in[7:0];   // byte0 = total_layers
            if (state == S_ERROR)
                total_layers_reg <= 8'd0;               // E-7
        end
    end

    // ----------------------------------------------------------
    // 3) E-1: العدّاد يزيد لحظة layer_done && softmax_done
    //    في S_WAIT_DONE — وليس في S_COMPUTE.
    //    الأولويات: تصفير بداية التوكن > زيادة Done > تصفير OUTPUT/ERROR.
    // ----------------------------------------------------------
    logic start_new_token;   // حافة الدخول إلى LOAD_META مع رأس صالح

    assign start_new_token = (next_state == S_LOAD_META) && metadata_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_count <= 8'd0;
        end else if (start_new_token) begin
            running_count <= 8'd0;                                   // E-7 بداية توكن
        end else if ((state == S_WAIT_DONE) && done_edge) begin
            running_count <= running_count + 8'd1;                   // ✨ الإصلاح الجوهري
        end else if ((state == S_OUTPUT_TOKEN) || (state == S_ERROR)) begin
            running_count <= 8'd0;                                   // E-7
        end
    end

    // ----------------------------------------------------------
    // 4) E-5: token_pending / token_pulse — إصدار آمن من دورة واحدة
    //    يتجمّع التوكن فور اكتمال الطبقة الأخيرة في WAIT_DONE،
    //    ثم تُصدر النبضة في دورة OUTPUT_TOKEN التالية.
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            token_pending <= 1'b0;
            token_pulse   <= 1'b0;
        end else begin
            token_pulse <= 1'b0;                              // افتراضياً نبضة واحدة
            if ((state == S_WAIT_DONE) && done_edge && current_is_last)
                token_pending <= 1'b1;
            else if (state == S_OUTPUT_TOKEN) begin
                token_pulse   <= token_pending;
                token_pending <= 1'b0;
            end else if ((state == S_IDLE) || (state == S_ERROR)) begin
                token_pending <= 1'b0;                        // E-7
            end
        end
    end

    // ----------------------------------------------------------
    // 5) منطق المخرجات التوافقي
    // ----------------------------------------------------------
    always_comb begin
        sel_external       = 1'b0;
        capture_loop       = 1'b0;
        start_layer        = 1'b0;
        weight_load_en     = 1'b0;
        weight_layer_idx   = 8'd0;
        output_token_valid = 1'b0;
        pipeline_busy      = (state != S_IDLE);
        state_out          = state;

        case (state)
            S_IDLE: begin
                sel_external = 1'b1;
            end

            S_LOAD_META: begin
                // لا مخرجات — التقاط الرأس فقط
            end

            S_PREFETCH_W: begin
                weight_load_en   = 1'b1;
                weight_layer_idx = running_count + 8'd1;   // شحن أوزان الطبقة الجارية
            end

            S_LOAD_LAYER_0: begin                          // E-2: حالة حية
                sel_external   = (running_count == 8'd0);  // الطبقة الأولى من الخارج
                weight_load_en = has_next_layer;           // تمهيد شحن الطبقة التالية
                if (has_next_layer)
                    weight_layer_idx = running_count + 8'd2;
            end

            S_COMPUTE: begin
                start_layer      = 1'b1;
                sel_external     = (running_count == 8'd0);
                capture_loop     = !current_is_last;       // لا التقاط بعد الطبقة الأخيرة
                weight_load_en   = has_next_layer;
                if (has_next_layer)
                    weight_layer_idx = running_count + 8'd2;
            end

            S_WAIT_DONE: begin
                capture_loop = !current_is_last;
            end

            S_LOOP_CHECK: begin
                // التقاط نتيجة الطبقة الجارية قبل أي انتقال للحساب التالي
                capture_loop = !is_last_layer;
            end

            S_OUTPUT_TOKEN: begin
                output_token_valid = token_pulse;          // E-5: نبضة مسجلة آمنة
            end

            S_ERROR: begin
                // كل المخرجات منخفضة ما عدا busy
            end

            default: ;
        endcase
    end

    // العرض: عدد الطبقات المكتملة فعلياً
    assign layer_counter_out = running_count;

endmodule
