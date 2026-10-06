//=============================================================================
// linear_relu_2layer
// Sequential two-layer Linear+ReLU on one OCCP systolic_array_param.
// Layer-1 INT32 accum -> on-chip requantize to INT8 -> layer-2 GEMV+ReLU.
//
// requant: hq = clip(round(y1 * scale1 / scale2), -127, 127)
// scale1 = product_scale layer1 (sw*sx), scale2 = INT8 scale of activations.
// Scales are IEEE-754 float32 words loaded from hex (simulation).
//=============================================================================

`ifndef SYNTHESIS
`timescale 1ns/1ps
`endif

module linear_relu_2layer #(
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

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_RUN1,
        ST_REQUANT,
        ST_RUN2,
        ST_DONE
    } state_t;

    state_t state;

    logic signed [DATA_WIDTH-1:0] W1_flat [0:N*N-1];
    logic signed [DATA_WIDTH-1:0] W2_flat [0:N*N-1];
    logic signed [DATA_WIDTH-1:0] x_mem   [0:N-1];
    logic signed [31:0]           b1_mem  [0:N-1];
    logic signed [31:0]           b2_mem  [0:N-1];
    logic [31:0]                  scale1_mem [0:0];
    logic [31:0]                  scale2_mem [0:0];
    logic signed [31:0]           ratio_mem  [0:0];

    initial begin
        string w1, w2, xfile, b1, b2, s1, s2, rq;
        w1    = "tests/golden/two_layer_4x4/weights1.hex";
        w2    = "tests/golden/two_layer_4x4/weights2.hex";
        xfile = "tests/golden/two_layer_4x4/input.hex";
        b1    = "tests/golden/two_layer_4x4/bias1.hex";
        b2    = "tests/golden/two_layer_4x4/bias2.hex";
        s1    = "tests/golden/two_layer_4x4/scale1.hex";
        s2    = "tests/golden/two_layer_4x4/scale2.hex";
        rq    = "tests/golden/two_layer_4x4/ratio_q24.hex";
        void'($value$plusargs("weights1=%s", w1));
        void'($value$plusargs("weights2=%s", w2));
        void'($value$plusargs("input=%s", xfile));
        void'($value$plusargs("bias1=%s", b1));
        void'($value$plusargs("bias2=%s", b2));
        void'($value$plusargs("scale1=%s", s1));
        void'($value$plusargs("scale2=%s", s2));
        void'($value$plusargs("ratio=%s", rq));
        $readmemh(w1, W1_flat);
        $readmemh(w2, W2_flat);
        $readmemh(xfile, x_mem);
        $readmemh(b1, b1_mem);
        $readmemh(b2, b2_mem);
        $readmemh(s1, scale1_mem);
        $readmemh(s2, scale2_mem);
        $readmemh(rq, ratio_mem);
    end

    logic        layer_sel;
    logic        busy;
    logic [15:0] cnt;
    logic        sa_en;
    logic        sa_clr;
    integer      feed;

    logic signed [DATA_WIDTH-1:0] W_flat [0:N*N-1];
    logic signed [31:0]           b_mem  [0:N-1];
    logic signed [N-1:0][DATA_WIDTH-1:0] inputs_a;
    logic signed [N-1:0][DATA_WIDTH-1:0] inputs_b;
    logic signed [N-1:0][N-1:0][ACCUM_WIDTH-1:0] sa_out;
    logic signed [31:0] acc_ext   [0:N-1];
    logic signed [31:0] pre_relu  [0:N-1];
    logic signed [31:0] post_relu [0:N-1];
    logic signed [31:0] y1_reg    [0:N-1];

    integer wi;
    always @(*) begin
        for (wi = 0; wi < N * N; wi = wi + 1)
            W_flat[wi] = layer_sel ? W2_flat[wi] : W1_flat[wi];
        for (wi = 0; wi < N; wi = wi + 1)
            b_mem[wi] = layer_sel ? b2_mem[wi] : b1_mem[wi];
    end

    assign sa_en  = busy;
    assign sa_clr = busy && (cnt == 16'd0);
    assign feed   = (cnt == 16'd0) ? 0 : (cnt - 1);

    systolic_array_param #(
        .DATA_WIDTH (DATA_WIDTH),
        .ARRAY_ROWS (N),
        .ARRAY_COLS (N)
    ) u_sa (
        .clk, .rst_n, .en(sa_en), .clr(sa_clr),
        .inputs_a, .inputs_b, .outputs(sa_out)
    );

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : relu_gen
            assign acc_ext[gi] = {{(32-ACCUM_WIDTH){sa_out[0][gi][ACCUM_WIDTH-1]}}, sa_out[0][gi]};
            assign pre_relu[gi] = acc_ext[gi] + b_mem[gi];
            relu_activation #(.DATA_WIDTH(32), .ACCUM_WIDTH(32)) u_relu (
                .accum_in(pre_relu[gi]), .relu_out(post_relu[gi])
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

    function automatic logic signed [7:0] requant_i32;
        input logic signed [31:0] acc;
        logic signed [63:0] prod;
        logic signed [31:0] rr;
        begin
            prod = acc * ratio_mem[0];
            if (prod >= 0)
                rr = (prod + 64'sd8388608) >>> 24;
            else
                rr = (prod - 64'sd8388608) >>> 24;
            if (rr > 32'sd127)
                rr = 32'sd127;
            if (rr < -32'sd127)
                rr = -32'sd127;
            requant_i32 = rr[7:0];
        end
    endfunction

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            busy      <= 1'b0;
            cnt       <= 16'd0;
            done      <= 1'b0;
            layer_sel <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                y_out[i] <= 32'sd0;
                y1_reg[i] <= 32'sd0;
            end
        end else begin
            done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (start) begin
                        layer_sel <= 1'b0;
                        busy      <= 1'b1;
                        cnt       <= 16'd0;
                        state     <= ST_RUN1;
                    end
                end
                ST_RUN1: begin
                    if (cnt == CAPTURE[15:0]) begin
                        busy <= 1'b0;
                        for (i = 0; i < N; i = i + 1)
                            y1_reg[i] <= post_relu[i];
                        state <= ST_REQUANT;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
                ST_REQUANT: begin
                    for (i = 0; i < N; i = i + 1)
                        x_mem[i] <= requant_i32(y1_reg[i]);
                    layer_sel <= 1'b1;
                    busy      <= 1'b1;
                    cnt       <= 16'd0;
                    state     <= ST_RUN2;
                end
                ST_RUN2: begin
                    if (cnt == CAPTURE[15:0]) begin
                        busy <= 1'b0;
                        for (i = 0; i < N; i = i + 1)
                            y_out[i] <= post_relu[i];
                        state <= ST_DONE;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
                ST_DONE: begin
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
