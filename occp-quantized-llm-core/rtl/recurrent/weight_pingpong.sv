// ============================================================
// weight_pingpong.sv
// Two parallel weight banks for bubble-free swapping, plus a built-in
// DMA address counter:
//   - Writes (from the DMA) always go to the bank opposite to the one
//     currently being read.
//   - load_en starts the internal counter; load_done emits a one-cycle
//     pulse once WEIGHT_DEPTH words have been loaded, and is wired as
//     weight_ready to the FSM.
// ============================================================
`timescale 1ns/1ps

module weight_pingpong #(
    parameter int DATA_WIDTH   = 16,
    parameter int WEIGHT_DEPTH = 4096
)(
    input  logic                            clk,
    input  logic                            rst_n,

    // Read-bank select (writes go to the opposite bank)
    input  logic                            buf_sel,   // 0=A, 1=B

    // DMA write interface
    input  logic                            load_en,
    input  logic [DATA_WIDTH-1:0]           load_data,
    output logic [$clog2(WEIGHT_DEPTH)-1:0] dma_addr,  // address driven by DMA

    // Read interface toward the systolic array
    input  logic [$clog2(WEIGHT_DEPTH)-1:0] read_addr,
    output logic [DATA_WIDTH-1:0]           weight_out,

    // Load-complete strobe (wired to FSM weight_ready)
    output logic                            load_done
);

    localparam int AW = $clog2(WEIGHT_DEPTH);

    logic [DATA_WIDTH-1:0] buf_a [0:WEIGHT_DEPTH-1];
    logic [DATA_WIDTH-1:0] buf_b [0:WEIGHT_DEPTH-1];

    // Zero-initialize to avoid x-values in simulation reads
    // (real behavior on fabricated SRG/BRAM comes from refresh/init).
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
            done_r <= 1'b0;                 // single-cycle pulse

            // Write into the bank opposite to the current read bank
            if (load_en) begin
                if (buf_sel) buf_a[cnt] <= load_data;
                else         buf_b[cnt] <= load_data;
            end

            if (load_en && !counting) begin
                counting <= 1'b1;           // start a new load round
            end else if (counting) begin
                if (cnt == AW'(WEIGHT_DEPTH-1)) begin
                    cnt      <= '0;
                    counting <= 1'b0;
                    done_r   <= 1'b1;       // round complete -> weight_ready
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

    assign load_done  = done_r;
    assign weight_out = buf_sel ? buf_b[read_addr] : buf_a[read_addr];

endmodule
