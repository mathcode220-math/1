// ============================================================
// layer_counter.sv
// عدّاد طبقات مع إشارات مقارنة
// ============================================================
`timescale 1ns/1ps

module layer_counter #(
    parameter int WIDTH = 8
)(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                inc,
    input  logic                clr,
    input  logic [WIDTH-1:0]    total_layers,
    output logic [WIDTH-1:0]    count,
    output logic                is_last
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)   count <= '0;
        else if (clr) count <= '0;
        else if (inc) count <= count + 1'b1;
    end

    // حماية من Underflow عندما total_layers = 0
    assign is_last = (total_layers != '0) && (count >= total_layers - 1'b1);

endmodule
