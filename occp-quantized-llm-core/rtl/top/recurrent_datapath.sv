// ============================================================
// recurrent_datapath.sv
// الحلقة العودية الكاملة: MUX + Layer + Loopback Register
// المسار خالٍ من الحلقات التوافقية: كل دورة تمر عبر سجلات.
// ناقلات المتجهات الداخلية مسطّحة (flat) لضمان سلوك نسخ
// متوقع ومتطابق بين جميع المحاكيات.
// ============================================================
`timescale 1ns/1ps

module recurrent_datapath #(
    parameter int DATA_WIDTH = 16,
    parameter int VECTOR_LEN = 512,
    parameter int LAYER_LATENCY = 3   // تأخير محاكاة الطبقة (دورات)
)(
    input  logic                         clk,
    input  logic                         rst_n,

    // التحكم من FSM
    input  logic                         sel_external,
    input  logic                         capture_loop,
    input  logic                         start_layer,
    output logic                         layer_done,

    // واجهة خارجية
    input  logic [DATA_WIDTH-1:0]        ext_data  [0:VECTOR_LEN-1],
    input  logic                         ext_valid,

    // المخرج النهائي
    output logic [DATA_WIDTH-1:0]        final_data [0:VECTOR_LEN-1],
    output logic                         final_valid
);

    localparam int LAT_W  = $clog2(LAYER_LATENCY+1);
    localparam int FLAT_W = DATA_WIDTH * VECTOR_LEN;

    // ----------------------------------------------------------
    // إشارات داخلية مسطّحة
    // ----------------------------------------------------------
    logic [FLAT_W-1:0] ext_flat;
    logic [FLAT_W-1:0] mux_flat;
    logic              mux_valid;

    logic [FLAT_W-1:0] cap_flat;
    logic              cap_valid;

    logic [FLAT_W-1:0] loop_flat;
    logic              loop_valid;

    logic [FLAT_W-1:0] layer_flat;
    logic              layer_valid;

    // تسطيح الإدخال الخارجي عنصرًا بعنصر
    always_comb begin
        for (int i = 0; i < VECTOR_LEN; i++)
            ext_flat[i*DATA_WIDTH +: DATA_WIDTH] = ext_data[i];
    end

    // ----------------------------------------------------------
    // MUX: خارجي مقابل مسار الحلقة (تشفير مباشر على الحزم المسطّحة)
    // ----------------------------------------------------------
    always_comb begin
        mux_flat  = sel_external ? ext_flat : loop_flat;
        mux_valid = sel_external ? ext_valid : loop_valid;
    end

    // ----------------------------------------------------------
    // التقاط لحظة بدء الطبقة (شحن المعاملات إلى Systolic Array).
    // الالتقاط يُثبّت البيانات طوال فترة الحساب فيمنع حلقة توافقية.
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cap_valid <= 1'b0;
            cap_flat  <= '0;
        end else begin
            cap_valid <= 1'b0;
            if (start_layer && mux_valid) begin
                cap_valid <= 1'b1;
                cap_flat  <= mux_flat;
            end
        end
    end

    // ----------------------------------------------------------
    // Layer stub — في الإنتاج يُستبدل بـ systolic_array_param الحقيقي.
    // عدّاد تنازلي يبدأ عند cap_valid؛ التسوية عندما cnt==2،
    // وlayer_valid نبضة دورتين (cnt==2 ثم cnt==1) تغطي نافذة الالتقاط.
    // ----------------------------------------------------------
    logic [LAT_W-1:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt         <= '0;
            layer_valid <= 1'b0;
            layer_flat  <= '0;
        end else begin
            layer_valid <= 1'b0;
            if (cap_valid) begin
                cnt <= LAT_W'(LAYER_LATENCY - 1);
            end else if (cnt != '0) begin
                cnt <= cnt - 1'b1;
                if (cnt == LAT_W'(2)) begin
                    layer_flat  <= cap_flat;
                    layer_valid <= 1'b1;   // حافة التسوية
                end else if (cnt == LAT_W'(1)) begin
                    layer_valid <= 1'b1;   // الدورة التالية: احتياطي الالتقاط
                end
            end
        end
    end

    // إشارة الانتهاء تُولَّد قبل دورة التسوية بواحدة حتى يلتقطها FSM
    assign layer_done = (cnt == LAT_W'(1));

    // ----------------------------------------------------------
    // Loopback Register: يكسر المسار التوافقي في الحلقة
    // (تنفيذ مسطّح مكافئ لوظيفة loopback_register)
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loop_valid <= 1'b0;
            loop_flat  <= '0;
        end else if (capture_loop & layer_valid) begin
            loop_valid <= 1'b1;
            loop_flat  <= layer_flat;
        end
    end

    // ----------------------------------------------------------
    // المخرج النهائي: صالح عندما لا نلتقط للحلقة (الطبقة الأخيرة)
    // ----------------------------------------------------------
    assign final_valid = layer_valid & ~capture_loop;

    genvar gi;
    generate
        for (gi = 0; gi < VECTOR_LEN; gi++) begin : g_unflat_final
            assign final_data[gi] = layer_flat[gi*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

endmodule
