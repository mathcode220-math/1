// ============================================================
// loopback_register.sv
// سجل مُفعَّل يكسر المسار التوافقي في الحلقة
// ============================================================
`timescale 1ns/1ps

module loopback_register #(
    parameter int DATA_WIDTH = 16,
    parameter int VECTOR_LEN = 512
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    en,
    input  logic [DATA_WIDTH-1:0]   data_in  [0:VECTOR_LEN-1],
    input  logic                    valid_in,
    output logic [DATA_WIDTH-1:0]   data_out [0:VECTOR_LEN-1],
    output logic                    valid_out
);

    // مسطّحة (flat) لضمان تحديث متزامن ومتوافق مع جميع المحاكيات
    localparam int FLAT_W = DATA_WIDTH * VECTOR_LEN;

    logic [FLAT_W-1:0] din_flat;
    logic [FLAT_W-1:0] dout_flat;

    always @(*) begin
        for (int i = 0; i < VECTOR_LEN; i++)
            din_flat[i*DATA_WIDTH +: DATA_WIDTH] = data_in[i];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            dout_flat <= '0;
        end else if (en) begin
            valid_out <= valid_in;
            dout_flat <= din_flat;
        end
    end

    always @(*) begin
        for (int i = 0; i < VECTOR_LEN; i++)
            data_out[i] = dout_flat[i*DATA_WIDTH +: DATA_WIDTH];
    end

endmodule
