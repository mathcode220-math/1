`timescale 1ns/1ps

module tb_weight_pingpong;

    localparam int DATA_WIDTH   = 8;
    localparam int WEIGHT_DEPTH = 16;

    logic                            clk = 0;
    logic                            rst_n;
    logic                            buf_sel;
    logic                            load_en;
    logic [DATA_WIDTH-1:0]           load_data;
    logic [$clog2(WEIGHT_DEPTH)-1:0] dma_addr;
    logic [$clog2(WEIGHT_DEPTH)-1:0] read_addr;
    logic [DATA_WIDTH-1:0]           weight_out;
    logic                            load_done;

    always #5 clk = ~clk;

    weight_pingpong #(
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_DEPTH(WEIGHT_DEPTH)
    ) dut (.*);

    int error_count = 0;

    initial begin
        #5000;
        $error("FAIL: watchdog timeout");
        $finish;
    end

    initial begin
        rst_n = 0;
        buf_sel = 0;
        load_en = 0;
        load_data = 0;
        read_addr = 0;
        #12 rst_n = 1;

        // ---- اختبار 1: شحن البنك B عبر DMA (نقرأ من A => نكتب في B) ----
        buf_sel = 0;
        @(negedge clk);
        load_en = 1;
        // نتابع dma_addr ونغذّي البيانات المطابقة له
        fork
            begin
                for (int i = 0; i < WEIGHT_DEPTH; i++) begin
                    while (dma_addr != i[$clog2(WEIGHT_DEPTH)-1:0]) @(negedge clk);
                    load_data = 8'hA0 + i[7:0];
                    @(negedge clk);
                end
                load_en = 0;
            end
        join

        wait (load_done === 1'b1);
        @(negedge clk);
        $display("OK: load_done pulse after full DMA round");

        // قراءة B بعد التبديل
        buf_sel = 1;
        for (int i = 0; i < WEIGHT_DEPTH; i++) begin
            read_addr = i[$clog2(WEIGHT_DEPTH)-1:0];
            #1;
            if (weight_out !== (8'hA0 + i[7:0])) begin
                $error("read fail at [%0d]: got %h expected %h",
                       i, weight_out, 8'hA0 + i[7:0]);
                error_count++;
            end
        end

        // ---- اختبار 2: Ping-Pong — نقرأ من A، ندمر B[5]=FE أثناء العد ----
        buf_sel = 0;                 // نقرأ من A، نكتب في B
        @(negedge clk);
        load_en   = 1;
        load_data = 8'h00;           // قيم غير مهمة قبل العنوان المستهدف
        // انتظر أن يصل عدّاد DMA إلى 5 ثم اكتب القيمة المميزة
        while (dma_addr != 4'd5) @(negedge clk);
        load_data = 8'hFE;
        @(negedge clk);              // الكتابة تتم على الحافة: B[5] <= FE
        load_en = 0;
        buf_sel = 1;
        read_addr = 4'd5;
        #1;
        if (weight_out !== 8'hFE) begin
            $error("Ping-Pong fail: B[5]=%h expected FE", weight_out);
            error_count++;
        end

        // ---- اختبار 3: bank A لم تُمس — قراءتها صفر ----
        buf_sel = 0;
        read_addr = 4'd0;
        #1;
        if (weight_out !== 8'h00) begin
            $error("Bank A should be untouched, got %h", weight_out);
            error_count++;
        end

        if (error_count == 0)
            $display("PASS: tb_weight_pingpong - all tests passed");
        else
            $error("FAIL: tb_weight_pingpong: %0d errors", error_count);
        $finish;
    end

endmodule
