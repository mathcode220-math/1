`timescale 1ns/1ps

// Testbench لوحدة occp_pipeline_fsm — المنافذ مسطّحة، بدون حزم في TB
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

    initial begin
        #20000;
        $error("FAIL: watchdog timeout");
        $finish;
    end

    // التقدم بحافة واحدة مع انتظار استقرار المخرجات التوافقية بعدها
    task automatic step();
        @(negedge clk);           // منتصف الدورة: تحديث المحفزات بأمان
        @(posedge clk); #1;       // الحافة تُلتقط ثم تستقر المخرجات
    endtask

    task automatic expect_state(string where, logic [3:0] exp);
        if (state_out !== exp) begin
            $error("%s: expected %s, got %s", where, state_name(exp), state_name(state_out));
            error_count++;
        end
    endtask

    // طبقة وسطى كاملة من WAIT_DONE الحالي حتى WAIT_DONE التالي
    task automatic run_middle_layer(int L);
        layer_done = 1'b1;
        @(negedge clk);                 // استقر layer_done قبل الحافة
        @(posedge clk); #1;
        layer_done = 1'b0;
        expect_state("loop-check", S_LOOP_CHECK);
        @(negedge clk);                 // LOOP_CHECK -> PREFETCH_W على الحافة التالية
        @(posedge clk); #1;
        expect_state("prefetch", S_PREFETCH_W);
        if (weight_load_en !== 1'b1) begin
            $error("L%0d: weight_load_en high in PREFETCH_W", L);
            error_count++;
        end
        weight_ready = 1'b1;
        @(negedge clk);
        @(posedge clk); #1;
        weight_ready = 1'b0;
        expect_state("compute", S_COMPUTE);
        if (start_layer !== 1'b1) begin
            $error("L%0d: start_layer pulse missing in COMPUTE", L);
            error_count++;
        end
        if (layer_counter_out !== (L+1)) begin
            $error("L%0d: layer_counter_out=%0d expected %0d", L, layer_counter_out, L+1);
            error_count++;
        end
        @(negedge clk);
        @(posedge clk); #1;             // COMPUTE -> WAIT_DONE
        expect_state("wait", S_WAIT_DONE);
        if (start_layer !== 1'b0) begin
            $error("L%0d: start_layer must be single-cycle pulse", L);
            error_count++;
        end
        if (capture_loop !== 1'b1) begin
            $error("L%0d: capture_loop high in WAIT_DONE", L);
            error_count++;
        end
    endtask

    initial begin
        rst_n=0; host_start=0; metadata_valid=0; layer_done=0;
        softmax_done=0; weight_ready=0; metadata_in='0;
        @(negedge clk);
        rst_n = 1;
        @(posedge clk); #1;

        // ---- T1: IDLE بعد إعادة الضبط ----
        if (state_out !== S_IDLE || pipeline_busy !== 1'b0) begin
            $error("T1: not in IDLE after reset");
            error_count++;
        end

        // ---- T2: host_start -> S_LOAD_META ----
        host_start = 1; @(negedge clk); @(posedge clk); #1; host_start = 0;
        expect_state("T2", S_LOAD_META);

        // ---- T3: التقاط total_layers ----
        metadata_in = 64'h0;
        metadata_in[7:0]   = 8'd3;    // total_layers = 3
        metadata_in[55:40] = 16'd4;   // vector_len = 4
        metadata_valid = 1; @(negedge clk); @(posedge clk); #1; metadata_valid = 0;
        expect_state("T3->PREFETCH", S_PREFETCH_W);
        if (dut.total_layers_reg !== 8'd3) begin
            $error("T3: total_layers_reg=%0d expected 3", dut.total_layers_reg);
            error_count++;
        end
        if (weight_load_en !== 1'b1) begin
            $error("T3: weight_load_en high in PREFETCH_W");
            error_count++;
        end

        // ---- T4: الطبقة الأولى external ----
        weight_ready = 1; @(negedge clk); @(posedge clk); #1; weight_ready = 0;
        expect_state("T4 compute", S_COMPUTE);
        if (start_layer !== 1'b1) begin
            $error("T4: start_layer pulse missing");
            error_count++;
        end
        if (sel_external !== 1'b1) begin
            $error("T4: sel_external high on layer 0 compute");
            error_count++;
        end
        if (layer_counter_out !== 8'd1) begin
            $error("T4: layer_counter_out=%0d expected 1", layer_counter_out);
            error_count++;
        end
        @(negedge clk); @(posedge clk); #1;   // -> WAIT_DONE
        expect_state("T4 wait", S_WAIT_DONE);
        if (capture_loop !== 1'b1) begin
            $error("T4: capture_loop high in WAIT_DONE");
            error_count++;
        end
        if (sel_external !== 1'b0) begin
            $error("T4: sel_external low outside first compute");
            error_count++;
        end

        // ---- T5: الطبقة الوسطى ----
        run_middle_layer(1);

        // ---- T6: الطبقة الأخيرة -> OUTPUT_TOKEN ----
        layer_done = 1; @(negedge clk); @(posedge clk); #1; layer_done = 0;
        expect_state("T6 loop-check", S_LOOP_CHECK);
        expect_state("T6 output", S_OUTPUT_TOKEN);   // انتقال فوري من LOOP_CHECK
        if (capture_loop !== 1'b0) begin
            $error("T6: capture_loop must stay low on final layer");
            error_count++;
        end
        if (layer_counter_out !== 8'd3) begin
            $error("T6: layer_counter_out=%0d expected 3", layer_counter_out);
            error_count++;
        end

        // ---- T7: softmax_done -> IDLE ----
        if (output_token_valid !== 1'b0) begin
            $error("T7: output_token_valid low before softmax_done");
            error_count++;
        end
        softmax_done = 1; #1;   // فحص توافقي داخل نفس دورة OUTPUT_TOKEN
        if (output_token_valid !== 1'b1) begin
            $error("T7: output_token_valid should assert with softmax_done");
            error_count++;
        end
        @(negedge clk); @(posedge clk); #1; softmax_done = 0;
        expect_state("T7 idle", S_IDLE);
        if (pipeline_busy !== 1'b0) begin
            $error("T7: pipeline_busy should drop in IDLE");
            error_count++;
        end

        // ---- T8: توكن ثانٍ بنموذج طبقة واحدة (الأولى = الأخيرة) ----
        host_start = 1; @(negedge clk); @(posedge clk); #1; host_start = 0;
        expect_state("T8 meta", S_LOAD_META);
        if (layer_counter_out !== 8'd0) begin
            $error("T8: counter resets at new token, got %0d", layer_counter_out);
            error_count++;
        end
        metadata_in[7:0] = 8'd1;
        metadata_valid = 1; @(negedge clk); @(posedge clk); #1; metadata_valid = 0;
        expect_state("T8 prefetch", S_PREFETCH_W);
        weight_ready = 1; @(negedge clk); @(posedge clk); #1; weight_ready = 0;
        expect_state("T8 compute", S_COMPUTE);
        if (capture_loop !== 1'b0) begin
            $error("T8: single-layer model must not capture loop");
            error_count++;
        end
        @(negedge clk); @(posedge clk); #1;   // WAIT_DONE
        layer_done = 1; @(negedge clk); @(posedge clk); #1; layer_done = 0;
        expect_state("T8 loop-check", S_LOOP_CHECK);
        expect_state("T8 output", S_OUTPUT_TOKEN);   // انتقال فوري
        softmax_done = 1; @(negedge clk); @(posedge clk); #1; softmax_done = 0;
        expect_state("T8 idle", S_IDLE);

        if (error_count == 0)
            $display("PASS: tb_occp_pipeline_fsm - all tests passed");
        else
            $error("FAIL: tb_occp_pipeline_fsm: %0d errors", error_count);
        $finish;
    end

endmodule
