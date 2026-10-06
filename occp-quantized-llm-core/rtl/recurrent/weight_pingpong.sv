// ============================================================
// weight_pingpong.sv
// بنكا أوزان متوازيان للتبديل بدون فقاعات
// ============================================================
`timescale 1ns/1ps

module weight_pingpong #(
    parameter int DATA_WIDTH   = 16,
    parameter int WEIGHT_DEPTH = 4096
)(
    input  logic                                clk,
    input  logic                                rst_n,

    // اختيار بنك القراءة؛ الكتابة تتم على البنك المعاكس دائمًا
    input  logic                                buf_sel,   // 0=القراءة من A، 1=القراءة من B

    // واجهة الكتابة من DMA
    input  logic                                load_en,
    input  logic [DATA_WIDTH-1:0]               load_data,
    input  logic [$clog2(WEIGHT_DEPTH)-1:0]     load_addr,

    // واجهة القراءة نحو Systolic Array
    input  logic [$clog2(WEIGHT_DEPTH)-1:0]     read_addr,
    output logic [DATA_WIDTH-1:0]               weight_out
);

    logic [DATA_WIDTH-1:0] buf_a [0:WEIGHT_DEPTH-1];
    logic [DATA_WIDTH-1:0] buf_b [0:WEIGHT_DEPTH-1];

    // الكتابة على البنك المعاكس لـ buf_sel (متزامن مع clk)
    always_ff @(posedge clk) begin
        if (load_en) begin
            if (buf_sel)
                buf_a[load_addr] <= load_data;  // نكتب في A عندما نقرأ من B
            else
                buf_b[load_addr] <= load_data;  // نكتب في B عندما نقرأ من A
        end
    end

    // قراءة غير متزامنة (asynchronous read) من البنك المختار
    assign weight_out = buf_sel ? buf_b[read_addr] : buf_a[read_addr];

endmodule
