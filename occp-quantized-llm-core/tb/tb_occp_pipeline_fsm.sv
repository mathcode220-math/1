`timescale 1ns/1ps

// ============================================================
// Testbench لوحدة occp_pipeline_fsm — النسخة المُصلَحة (E-6)
// القواعد:
//   * بعد كل فحص حالة يجب الانتظار حافة كاملة قبل الفحص التالي.
//   * لا يوجد انتقال فوري LOOP_CHECK -> OUTPUT_TOKEN في نفس الحافة؛
//     بينهما حافة واحدة على الأقل.
//   * S_LOAD_LAYER_0 حالة حية الآن في المسار (E-2).
//   * WAIT_DONE يشترط layer_done && softmax_done معاً (E-3).
// ============================================================
module tb_occp_pipeline_fsm;

    localparam logic [3:0] S_IDLE          = 4'd0;
    localparam logic [3:0] S_LOAD_META     = 4'd1;
    localparam logic [3:0] S_PREFETCH_W    = 4'd2;
    localparam logic [3:0] S_LOAD_LAYER_0  = 4'd3;
    localparam logic [3:0] S_COMPUTE       = 4'd4;
    localparam logic [3:0] S_WAIT_DONE     = 4'd5;
    localparam logic [3:0] S_LOOP_CHECK    = 4'd6;
    localparam logic [3:0] S_OUTPUT_TOKEN  = 4'd7;
    localparam logic [3:0] S_ERROR         = 4'd8;

    function automatic string state_name(logic [3:0] st);
        case (st)
            S_IDLE:          return "S_IDLE";
            S_LOAD_META:     return "S_LOAD_META";
            S_PREFETCH_W:    return "S_PREFETCH_W";
            S_LOAD_LAYER_0:  return "S_LOAD_LAYER_0";
            S_COMPUTE:       return "S_COMPUTE";
            S_WAIT_DONE:     return "S_WAIT_DONE";
            S_LOOP_CHECK:    return "S_LOOP_CHECK";
            S_OUTPUT_TOKEN:  return "S_OUTPUT_TOKEN";
            S_ERROR:         return "S_ERROR";
            default:         return "UNKNOWN";
        endcase
    endfunction

    logic clk = 0, rst_n;
    logic host_start;
    logic [63:0] metadata_in;
    logic metadata_valid;
    logic layer_done, softmax_done, weight_ready;
    logic sel_external, capture_loop, start_layer, buf_sel, weight_load_en;
    logic [7:0] weight_layer_idx, layer_counter_out;
    logic output_token_valid, pipeline_busy;
    logic [3:0] state_out;

    always #5 clk = ~clk;

    occp_pipeline_fsm dut (.*);

    int error_count = 0;
    int token_pulses_seen = 0;

    // مراقب نبضات التوكن (يجب أن تكون دورة واحدة بالضبط لكل توكن)
    always @(posedge clk) begin
        if (output_token_valid === 1'b1) token_pulses_seen++;
    end

    initial begin
        #50000;
        $error("FAIL: watchdog timeout");
        $finish;
    end

    task automatic expect_state(string where, logic [3:0] exp);
        if (state_out !== exp) begin
            $error("%s: expected %s, got %s", where, state_name(exp), state_name(state_out));
            error_count++;
        end
    endtask

    task automatic expect_eq8(string where, logic [7:0] got, logic [7:0] exp);
        if (got !== exp) begin
            $error("%s: got %0d expected %0d", where, got, exp);
            error_count++;
        end
    endtask

    // التقدم بحافة كاملة واحدة
    task automatic step();
        @(negedge clk);
        @(posedge clk); #1;
    endtask

    // ----------------------------------------------------------
    // طبقة كاملة: من PREFETCH_W حتى WAIT_DONE التالي
    // L = رقم الطبقة (0-based) الجارية
    // ----------------------------------------------------------
    task automatic run_full_layer(int L, int last);
        // PREFETCH_W: weight_load_en مرتفع وفهرس الشحن = L+1 (1-based)
        expect_state($sformatf("L%0d prefetch", L), S_PREFETCH_W);
        if (weight_load_en !== 1'b1) begin
            $error("L%0d: weight_load_en not high in PREFETCH_W", L);
            error_count++;
        end
        expect_eq8($sformatf("L%0d load idx", L), weight_layer_idx, L[7:0] + 8'd1);
        step();  // -> LOAD_LAYER_0 (E-2: حالة حية)

        expect_state($sformatf("L%0d load-layer-0", L), S_LOAD_LAYER_0);
        if (L == 0) begin
            if (sel_external !== 1'b1) begin
                $error("L0: sel_external must be high in LOAD_LAYER_0");
                error_count++;
            end
        end
        if (!last) begin
            expect_eq8($sformatf("L%0d next idx in LOAD0", L),
                       weight_layer_idx, L[7:0] + 8'd2);
        end
        step();  // -> COMPUTE

        expect_state($sformatf("L%0d compute", L), S_COMPUTE);
        if (start_layer !== 1'b1) begin
            $error("L%0d: start_layer pulse missing in COMPUTE", L);
            error_count++;
        end
        if (sel_external !== ((L == 0) ? 1'b1 : 1'b0)) begin
            $error("L%0d: sel_external=%b unexpected", L, sel_external);
            error_count++;
        end
        if (buf_sel !== ((L[0] == 1'b0) ? 1'b1 : 1'b0)) begin
            $error("L%0d: buf_sel=%b expected %b (layer bank = (L+1)[0])",
                   L, buf_sel, (L[0] == 1'b0));
            error_count++;
        end
        expect_eq8($sformatf("L%0d counter during compute", L),
                   layer_counter_out, L[7:0]);
        step();  // -> WAIT_DONE

        expect_state($sformatf("L%0d wait", L), S_WAIT_DONE);
        if (start_layer !== 1'b0) begin
            $error("L%0d: start_layer must be single-cycle pulse", L);
            error_count++;
        end
        if (capture_loop !== (last ? 1'b0 : 1'b1)) begin
            $error("L%0d: capture_loop=%b expected %b", L, capture_loop, !last);
            error_count++;
        end

        // نغادر WAIT_DONE عند الحافة التالية — لا شيء يُفعّل هنا.
    endtask

    // إتمام طبقة من WAIT_DONE الحالي: فحص E-3 ثم الإكمال إلى PREFETCH_W
    // (أو OUTPUT_TOKEN إذا كانت last). تنتهي المهمة بعد حافة المغادرة.
    task automatic finish_layer(int L, int last);
        // E-3: layer_done وحده لا يكفي — تبقى الآلة في WAIT_DONE
        @(negedge clk);
        layer_done = 1'b1; softmax_done = 1'b0;
        @(posedge clk); #1;
        expect_state($sformatf("L%0d still waiting (no softmax)", L), S_WAIT_DONE);
        expect_eq8($sformatf("L%0d counter not advanced w/o softmax", L),
                   layer_counter_out, L[7:0]);

        // الاثنتان معاً -> الحافة التالية تغادر WAIT_DONE (العدّاد يتقدم E-1)
        @(negedge clk);
        softmax_done = 1'b1;   // layer_done ما زال مرتفعاً
        @(posedge clk); #1;
        layer_done = 1'b0; softmax_done = 1'b0;
        expect_state($sformatf("L%0d loop-check", L), S_LOOP_CHECK);
        expect_eq8($sformatf("L%0d counter after done", L),
                   layer_counter_out, L[7:0] + 8'd1);
        // حافة المغادرة من LOOP_CHECK: غير الأخيرة -> PREFETCH_W، الأخيرة -> OUTPUT_TOKEN
        step();
        if (!last)
            expect_state($sformatf("L%0d next prefetch", L), S_PREFETCH_W);
    endtask

    initial begin
        rst_n=0; host_start=0; metadata_valid=0; layer_done=0;
        softmax_done=0; weight_ready=0; metadata_in='0;
        @(negedge clk);
        rst_n = 1;
        step();

        // ---- T1: IDLE بعد إعادة الضبط ----
        expect_state("T1", S_IDLE);
        if (pipeline_busy !== 1'b0) begin
            $error("T1: pipeline_busy should be low in IDLE");
            error_count++;
        end

        // ---- T2: host_start بدون metadata -> يبقى IDLE ----
        @(negedge clk); host_start = 1;
        @(posedge clk); #1;
        @(negedge clk); host_start = 0;
        expect_state("T2 no-metadata stays idle", S_IDLE);

        // ---- T3: نفس حافة host_start+metadata_valid -> LOAD_META ----
        @(negedge clk);
        metadata_in = '0;
        metadata_in[7:0] = 8'd3;                 // total_layers = 3
        host_start = 1; metadata_valid = 1;
        @(posedge clk); #1;
        @(negedge clk);
        host_start = 0; metadata_valid = 0;
        expect_state("T3 load-meta", S_LOAD_META);
        if (dut.total_layers_reg !== 8'd3) begin
            $error("T3: total_layers_reg=%0d expected 3", dut.total_layers_reg);
            error_count++;
        end
        step();                                   // LOAD_META -> PREFETCH_W دائماً
        expect_state("T3->PREFETCH", S_PREFETCH_W);

        // ---- الطبقات الثلاث كاملة ----
        weight_ready = 1;
        run_full_layer(0, 0);  finish_layer(0, 0);
        run_full_layer(1, 0);  finish_layer(1, 0);
        run_full_layer(2, 1);  finish_layer(2, 1);

        // ---- نحن الآن داخل OUTPUT_TOKEN (E-6: حافة واحدة بعد LOOP_CHECK) ----
        weight_ready = 0;
        expect_state("output-token", S_OUTPUT_TOKEN);
        if (layer_counter_out !== 8'd3) begin
            $error("expected layer_counter_out=3, got %0d", layer_counter_out);
            error_count++;
        end
        if (output_token_valid !== 1'b1) begin
            $error("token pulse missing in first OUTPUT_TOKEN cycle");
            error_count++;
        end
        step();  // token_pending=0 -> IDLE والنبضة انتهت
        expect_state("idle after token", S_IDLE);
        if (output_token_valid !== 1'b0) begin
            $error("token pulse must be exactly one cycle");
            error_count++;
        end
        if (pipeline_busy !== 1'b0) begin
            $error("pipeline_busy should drop in IDLE");
            error_count++;
        end
        if (token_pulses_seen != 1) begin
            $error("expected exactly 1 token pulse, saw %0d", token_pulses_seen);
            error_count++;
        end

        // ---- توكن ثانٍ بنموذج طبقة واحدة (الأولى = الأخيرة) ----
        @(negedge clk);
        metadata_in[7:0] = 8'd1;
        host_start = 1; metadata_valid = 1;
        @(posedge clk); #1;
        @(negedge clk);
        host_start = 0; metadata_valid = 0;
        expect_state("T2 meta", S_LOAD_META);
        if (layer_counter_out !== 8'd0) begin
            $error("counter must reset for new token, got %0d", layer_counter_out);
            error_count++;
        end
        step();
        expect_state("T2 prefetch", S_PREFETCH_W);
        weight_ready = 1;
        run_full_layer(0, 1);  finish_layer(0, 1);
        weight_ready = 0;
        expect_state("T2 output", S_OUTPUT_TOKEN);
        if (output_token_valid !== 1'b1) begin
            $error("second token pulse missing");
            error_count++;
        end
        step();
        expect_state("T2 idle final", S_IDLE);
        if (token_pulses_seen != 2) begin
            $error("expected 2 token pulses total, saw %0d", token_pulses_seen);
            error_count++;
        end

        if (error_count == 0)
            $display("PASS: tb_occp_pipeline_fsm - all tests passed");
        else
            $error("FAIL: tb_occp_pipeline_fsm: %0d errors", error_count);
        $finish;
    end

endmodule
