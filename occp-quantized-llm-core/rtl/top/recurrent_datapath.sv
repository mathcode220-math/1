// ============================================================
// recurrent_datapath.sv
// الحلقة العودية الكاملة: MUX + Layer + Loopback Register
// ============================================================
`timescale 1ns/1ps

module recurrent_datapath #(
    parameter int DATA_WIDTH = 16,
    parameter int VECTOR_LEN = 512
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

    // مسار الحلقة
    logic [DATA_WIDTH-1:0] mux_data  [0:VECTOR_LEN-1];
    logic                  mux_valid;
    logic [DATA_WIDTH-1:0] layer_out [0:VECTOR_LEN-1];
    logic                  layer_valid;
    logic [DATA_WIDTH-1:0] loop_data [0:VECTOR_LEN-1];
    logic                  loop_valid;

    // MUX
    layer_loopback_mux #(
        .DATA_WIDTH(DATA_WIDTH),
        .VECTOR_LEN(VECTOR_LEN)
    ) u_mux (
        .sel_external (sel_external),
        .ext_data     (ext_data),
        .ext_valid    (ext_valid),
        .loop_data    (loop_data),
        .loop_valid   (loop_valid),
        .mux_data     (mux_data),
        .mux_valid    (mux_valid)
    );

    // Layer stub — في الإنتاج يُستبدل بـ systolic_array_param الحقيقي
    // هنا: نمرر البيانات مع تأخير 3 دورات لمحاكاة الحساب
    logic [1:0] delay_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt <= '0;
            layer_valid <= 1'b0;
            for (int i = 0; i < VECTOR_LEN; i++) layer_out[i] <= '0;
        end else if (start_layer && mux_valid) begin
            delay_cnt <= 2'd3;
        end else if (delay_cnt > 0) begin
            if (delay_cnt == 1) begin
                // Icarus لا يدعم إسناد مصفوفة كاملة — ننسخ عنصرًا عنصرًا
                for (int i = 0; i < VECTOR_LEN; i++) layer_out[i] <= mux_data[i];
                layer_valid <= 1'b1;
            end
            delay_cnt <= delay_cnt - 1'b1;
        end else begin
            layer_valid <= 1'b0;
        end
    end

    assign layer_done = (delay_cnt == 1);

    // Loopback Register
    loopback_register #(
        .DATA_WIDTH(DATA_WIDTH),
        .VECTOR_LEN(VECTOR_LEN)
    ) u_loop_reg (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (capture_loop),
        .data_in   (layer_out),
        .valid_in  (layer_valid),
        .data_out  (loop_data),
        .valid_out (loop_valid)
    );

    // المخرج النهائي
    assign final_data  = layer_out;
    assign final_valid = layer_valid & ~capture_loop;

endmodule
