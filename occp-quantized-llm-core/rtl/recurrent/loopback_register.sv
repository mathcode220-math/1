// ============================================================
// loopback_register.sv
// Enabled register that breaks the combinational path inside the
// recurrent loop. Data is captured only when en is asserted.
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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            for (int i = 0; i < VECTOR_LEN; i++) data_out[i] <= '0;
        end else if (en) begin
            valid_out <= valid_in;
            for (int i = 0; i < VECTOR_LEN; i++) data_out[i] <= data_in[i];
        end
    end

endmodule
