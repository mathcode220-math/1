//=============================================================================
// linear_relu — parameterized GEMV + bias + ReLU around OCCP systolic array.
// Hex paths via plusargs: +weights= +input= +bias=
//=============================================================================

`ifndef SYNTHESIS
`timescale 1ns/1ps
`endif

module linear_relu #(
    parameter N           = 4,
    parameter DATA_WIDTH  = 8,
    parameter EXTRA_BITS  = $clog2(N * N) + 1,
    parameter ACCUM_WIDTH = 2 * DATA_WIDTH + EXTRA_BITS
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      start,
    output logic                      done,
    output logic signed [N-1:0][31:0] y_out
);

    localparam CAPTURE = 2 * N + 2;

    logic signed [DATA_WIDTH-1:0] W_flat [0:N*N-1];
    logic signed [DATA_WIDTH-1:0] x_mem  [0:N-1];
    logic signed [31:0]           b_mem  [0:N-1];

    initial begin
        string wfile, xfile, bfile;
        wfile = "results/weights.hex";
        xfile = "results/input.hex";
        bfile = "results/bias.hex";
        void'($value$plusargs("weights=%s", wfile));
        void'($value$plusargs("input=%s", xfile));
        void'($value$plusargs("bias=%s", bfile));
        $readmemh(wfile, W_flat);
        $readmemh(xfile, x_mem);
        $readmemh(bfile, b_mem);
    end

    logic        busy;
    logic [15:0] cnt;
    logic        sa_en;
    logic        sa_clr;
    integer      feed;

    logic signed [N-1:0][DATA_WIDTH-1:0] inputs_a;
    logic signed [N-1:0][DATA_WIDTH-1:0] inputs_b;
    logic signed [N-1:0][N-1:0][ACCUM_WIDTH-1:0] sa_out;

    logic signed [31:0] acc_ext   [0:N-1];
    logic signed [31:0] pre_relu  [0:N-1];
    logic signed [31:0] post_relu [0:N-1];

    assign sa_en  = busy;
    assign sa_clr = busy && (cnt == 16'd0);
    assign feed   = (cnt == 16'd0) ? 0 : (cnt - 1);

    systolic_array_param #(
        .DATA_WIDTH (DATA_WIDTH),
        .ARRAY_ROWS (N),
        .ARRAY_COLS (N)
    ) u_sa (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (sa_en),
        .clr      (sa_clr),
        .inputs_a (inputs_a),
        .inputs_b (inputs_b),
        .outputs  (sa_out)
    );

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : relu_gen
            assign acc_ext[gi] = {{(32-ACCUM_WIDTH){sa_out[0][gi][ACCUM_WIDTH-1]}}, sa_out[0][gi]};
            assign pre_relu[gi] = acc_ext[gi] + b_mem[gi];
            relu_activation #(
                .DATA_WIDTH  (32),
                .ACCUM_WIDTH (32)
            ) u_relu (
                .accum_in (pre_relu[gi]),
                .relu_out (post_relu[gi])
            );
        end
    endgenerate

    integer r, c, k;
    always @(*) begin
        inputs_a = '0;
        inputs_b = '0;
        if (busy && !sa_clr) begin
            k = feed;
            if (k >= 0 && k < N)
                inputs_a[0] = x_mem[k];
            for (r = 1; r < N; r = r + 1)
                inputs_a[r] = '0;
            for (c = 0; c < N; c = c + 1) begin
                k = feed - c;
                if (k >= 0 && k < N)
                    inputs_b[c] = W_flat[k*N + c];
            end
        end
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            cnt  <= 16'd0;
            done <= 1'b0;
            for (i = 0; i < N; i = i + 1)
                y_out[i] <= 32'sd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                cnt  <= 16'd0;
            end else if (busy) begin
                if (cnt == CAPTURE[15:0]) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    for (i = 0; i < N; i = i + 1)
                        y_out[i] <= post_relu[i];
                end else begin
                    cnt <= cnt + 16'd1;
                end
            end
        end
    end

endmodule
