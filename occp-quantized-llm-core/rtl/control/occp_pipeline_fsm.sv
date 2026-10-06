// ============================================================
// occp_pipeline_fsm.sv
// الدماغ: يدير الحلقة العودية عبر الطبقات
// ============================================================
`timescale 1ns/1ps

import model_metadata_pkg::*;

module occp_pipeline_fsm #(
    parameter int MAX_LAYERS = 128
)(
    input  logic                clk,
    input  logic                rst_n,

    // واجهة Host
    input  logic                host_start,
    output logic                host_busy,

    // Metadata
    input  model_header_t       metadata_in,
    input  logic                metadata_valid,

    // Datapath
    output logic                sel_external,
    output logic                capture_loop,
    output logic                start_layer,
    input  logic                layer_done,
    input  logic                softmax_done,

    // الأوزان
    output logic                buf_sel,
    output logic                weight_load_en,
    output logic [7:0]          weight_layer_idx,
    input  logic                weight_ready,

    // المخرجات
    output logic                output_token_valid,
    output logic [7:0]          layer_counter_out
);

    fsm_state_t state, next_state;

    logic [7:0] layer_counter;
    logic [7:0] total_layers;
    logic       is_last_layer;

    // ------------------------------------------------------------
    // التقاط Metadata وعدّاد الطبقات (سجلات)
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_layers  <= '0;
            layer_counter <= '0;
        end else begin
            case (state)
                S_LOAD_META: begin
                    total_layers  <= metadata_in.total_layers;
                    layer_counter <= 8'd0;
                end

                S_LOOP_CHECK: begin
                    if (!is_last_layer)
                        layer_counter <= layer_counter + 1'b1;
                end

                S_OUTPUT_TOKEN: begin
                    layer_counter <= 8'd0;
                    total_layers  <= 8'd0;
                end

                default: ;
            endcase
        end
    end

    assign is_last_layer     = (total_layers != 8'd0) &&
                               (layer_counter >= total_layers - 1'b1);
    assign layer_counter_out = layer_counter;

    // "بنك الطبقة التالية" = الطبقة التي ستُحسب تالياً بعد اكتمال الحالية
    wire [7:0] next_layer_bank = ((layer_counter + 8'd1) >= total_layers)
                                 ? 8'd0
                                 : (layer_counter + 8'd1);

    // ------------------------------------------------------------
    // منطق الانتقال
    // ------------------------------------------------------------
    always_comb begin
        next_state = state;
        unique case (state)
            S_IDLE: begin
                if (host_start && metadata_valid)
                    next_state = S_LOAD_META;
            end

            S_LOAD_META: begin
                next_state = S_PREFETCH_W;
            end

            S_PREFETCH_W: begin
                if (weight_ready)
                    next_state = S_LOAD_LAYER_0;
            end

            S_LOAD_LAYER_0: begin
                next_state = S_COMPUTE;
            end

            S_COMPUTE: begin
                next_state = S_WAIT_DONE;
            end

            S_WAIT_DONE: begin
                if (layer_done && softmax_done)
                    next_state = S_LOOP_CHECK;
            end

            S_LOOP_CHECK: begin
                if (is_last_layer)
                    next_state = S_OUTPUT_TOKEN;
                else
                    next_state = S_PREFETCH_W;   // تحميل أوزان الطبقة التالية ثم حسابها
            end

            S_OUTPUT_TOKEN: begin
                next_state = S_IDLE;             // نبضة حالة واحدة ثم العودة
            end

            S_ERROR: begin
                if (!host_start)
                    next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // سجل الحالة
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // ------------------------------------------------------------
    // منطق المخرجات (توافقي من الحالة + العدّاد)
    // ------------------------------------------------------------
    always_comb begin
        sel_external       = 1'b0;
        capture_loop       = 1'b0;
        start_layer        = 1'b0;
        buf_sel            = 1'b0;
        weight_load_en     = 1'b0;
        weight_layer_idx   = 8'd0;
        output_token_valid = 1'b0;
        host_busy          = 1'b1;

        unique case (state)
            S_IDLE: begin
                host_busy    = 1'b0;
                sel_external = 1'b1;
            end

            S_LOAD_META: begin
                // لا مخرجات فعلية
            end

            S_PREFETCH_W: begin
                // تحميل بنك الطبقة الجارية (يُقرأ منه الحساب القادم)
                buf_sel          = layer_counter[0];
                weight_load_en   = 1'b1;
                weight_layer_idx = layer_counter;
            end

            S_LOAD_LAYER_0: begin
                sel_external     = 1'b1;
                buf_sel          = layer_counter[0];
                weight_load_en   = 1'b1;
                weight_layer_idx = layer_counter;
            end

            S_COMPUTE: begin
                start_layer      = 1'b1;
                sel_external     = (layer_counter == 8'd0);
                capture_loop     = (layer_counter != 8'd0);
                buf_sel          = layer_counter[0];
                weight_load_en   = 1'b1;           // تحمّل مسبق لبنك الطبقة التالية
                weight_layer_idx = next_layer_bank;
            end

            S_WAIT_DONE: begin
                capture_loop = (layer_counter != 8'd0);
                buf_sel      = layer_counter[0];
            end

            S_LOOP_CHECK: begin
                capture_loop = 1'b1;               // التقاط ناتج الطبقة المكتملة
            end

            S_OUTPUT_TOKEN: begin
                output_token_valid = 1'b1;
            end

            S_ERROR: begin
                host_busy = 1'b1;
            end

            default: ;
        endcase
    end

endmodule
