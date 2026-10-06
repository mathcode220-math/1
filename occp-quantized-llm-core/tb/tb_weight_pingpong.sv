`timescale 1ns/1ps

module tb_weight_pingpong;

    localparam int DATA_WIDTH   = 8;
    localparam int WEIGHT_DEPTH = 16;

    logic                                clk = 0;
    logic                                rst_n;
    logic                                buf_sel;
    logic                                load_en;
    logic [DATA_WIDTH-1:0]               load_data;
    logic [$clog2(WEIGHT_DEPTH)-1:0]     load_addr;
    logic [$clog2(WEIGHT_DEPTH)-1:0]     read_addr;
    wire  logic [DATA_WIDTH-1:0]         weight_out;

    always #5 clk = ~clk;

    weight_pingpong #(
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_DEPTH(WEIGHT_DEPTH)
    ) dut (.*);

    int error_count = 0;

    initial begin
        #1;
        rst_n = 0;
        buf_sel = 0;
        load_en = 0;
        load_data = 0;
        load_addr = 0;
        read_addr = 0;
        #11 rst_n = 1;

        // اختبار 1: شحن البنك المعاكس ثم القراءة منه
        // buf_sel=0 => القراءة من A، الكتابة في B
        buf_sel = 0;
        for (int i = 0; i < WEIGHT_DEPTH; i++) begin
            @(negedge clk);
            load_en   = 1;
            load_addr = i[$clog2(WEIGHT_DEPTH)-1:0];
            load_data = 8'hA0 + i[7:0];
        end
        @(negedge clk); load_en = 0;

        // الآن B تحتوي على البيانات، نقرأ منها بتبديل buf_sel
        buf_sel = 1;
        for (int i = 0; i < WEIGHT_DEPTH; i++) begin
            read_addr = i[$clog2(WEIGHT_DEPTH)-1:0];
            #1;
            if (weight_out !== (8'hA0 + i[7:0])) begin
                $error("read failed at [%0d]: %h, expected %h",
                       i, weight_out, 8'hA0 + i[7:0]);
                error_count++;
            end
        end

        // اختبار 2: كتابة متزامنة أثناء القراءة (Ping-Pong حقيقي)
        // ملاحظة: الكتابة تتم على البنك المعاكس لـ buf_sel، لذا
        // مع buf_sel=1 (القراءة من B) تُكتب البيانات في A.
        // نُبقي buf_sel=1 أثناء النبضة ثم نقرأ من A بعد التبديل.
        @(negedge clk);
        load_en   = 1;
        load_addr = 4'h5;
        load_data = 8'hEE;
        @(posedge clk); #1;              // الكتابة تمت عند هذه الحافة (إلى A)
        load_en = 0;
        // A[5] يجب أن يكون EE الآن
        buf_sel   = 0;
        read_addr = 4'h5;
        #1;
        if (weight_out !== 8'hEE) begin
            $error("ping-pong failed: A[5] = %h, expected EE", weight_out);
            error_count++;
        end

        if (error_count == 0)
            $display("PASS: tb_weight_pingpong - all tests passed");
        else
            $error("FAIL: tb_weight_pingpong - %0d errors", error_count);

        $finish;
    end

endmodule
