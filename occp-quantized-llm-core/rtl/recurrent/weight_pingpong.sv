// ============================================================
// weight_pingpong.sv
// بنكا أوزان متوازيان للتبديل بدون فقاعات + عدّاد DMA مدمج
//   - الكتابة (من DMA) تتم دائماً في البنك المعاكس لبنك القراءة.
//   - load_en يفعّل العدّاد الداخلي؛ load_done تُصدر نبضة أحادية
//     الدورة عند اكتمال شحن WEIGHT_DEPTH كلمة، وتُستخدم كـ
//     weight_ready للـ FSM.
// ============================================================
`timescale 1ns/1ps

module weight_pingpong #(
    parameter int DATA_WIDTH   = 16,
    parameter int WEIGHT_DEPTH = 4096
)(
    input  logic                                clk,
    input  logic                                rst_n,

    // اختيار بنك القراءة (الكتابة تحدث في البنك المعاكس)
    input  logic                                buf_sel,   // 0=A, 1=B

    // واجهة الكتابة من DMA
    input  logic                                load_en,
    input  logic [DATA_WIDTH-1:0]               load_data,
    output logic [$clog2(WEIGHT_DEPTH)-1:0]     dma_addr,  // عنوان يكتبه الـ DMA

    // واجهة القراءة نحو Systolic Array
    input  logic [$clog2(WEIGHT_DEPTH)-1:0]     read_addr,
    output logic [DATA_WIDTH-1:0]               weight_out,

    // إشارة اكتمال الشحن (توصَل إلى weight_ready في FSM)
    output logic                                load_done
);

    localparam int AW = $clog2(WEIGHT_DEPTH);

    logic [DATA_WIDTH-1:0] buf_a [0:WEIGHT_DEPTH-1];
    logic [DATA_WIDTH-1:0] buf_b [0:WEIGHT_DEPTH-1];

    // تهيئة بـ 0 لتجنب قيم x في قراءات المحاكاة (سلوك PRG عند التصنيع)
    initial begin
        for (int i = 0; i < WEIGHT_DEPTH; i++) begin
            buf_a[i] = '0;
            buf_b[i] = '0;
        end
    end

    logic [AW-1:0] cnt;
    logic          counting;
    logic          done_r;

    assign dma_addr = cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt      <= '0;
            counting <= 1'b0;
            done_r   <= 1'b0;
        end else begin
            done_r <= 1'b0;                 // نبضة أحادية الدورة

            // الكتابة في البنك المعاكس لبنك القراءة الحالي
            if (load_en) begin
                if (buf_sel) buf_a[cnt] <= load_data;
                else         buf_b[cnt] <= load_data;
            end

            if (load_en && !counting) begin
                counting <= 1'b1;           // بدء جولة شحن جديدة
            end else if (counting) begin
                if (cnt == AW'(WEIGHT_DEPTH-1)) begin
                    cnt      <= '0;
                    counting <= 1'b0;
                    done_r   <= 1'b1;       // اكتملت الجولة → weight_ready
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

    assign load_done  = done_r;
    assign weight_out = buf_sel ? buf_b[read_addr] : buf_a[read_addr];

endmodule
