// ============================================================
// sa_done_generator.sv
// Generates a real "done" strobe based on a programmable latency
// counter, modeling systolic-array compute completion.
// ============================================================
`timescale 1ns/1ps

module sa_done_generator #(
    parameter int LATENCY_WIDTH = 8
)(
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        start,
    input  logic [LATENCY_WIDTH-1:0]    latency_cfg,  // programmable latency
    output logic                        done
);

    logic [LATENCY_WIDTH-1:0] counter;
    logic                     active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
            active  <= 1'b0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start) begin
                counter <= latency_cfg - 1'b1;
                active  <= 1'b1;
            end else if (active) begin
                if (counter == '0) begin
                    done   <= 1'b1;
                    active <= 1'b0;
                end else begin
                    counter <= counter - 1'b1;
                end
            end
        end
    end

endmodule
