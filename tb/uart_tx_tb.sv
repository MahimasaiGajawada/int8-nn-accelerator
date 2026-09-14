module uart_tx_tb();

    logic clk, rst, start, busy, tx;
    logic [7:0] data;

    integer i;
    logic test_pass;

    localparam DATA_WIDTH = 8;

    uart_tx #(.DATA_WIDTH(8), .CLKS_PER_BIT(104)) dut(.clk(clk), .rst(rst), .start(start), .data(data), .tx(tx), .busy(busy));

    always #5 clk = ~clk;

    task automatic test_uart_tx();
        clk = 0;
        rst = 1;
        start = 0;
        data = 0;
        test_pass = 1;
        @(posedge clk);

        rst = 0;

        data = 8'b10100101;

        start = 1;
        @(negedge clk);
        start = 0;

        if (!busy) begin
            $display("FAIL: busy never asserted");
            test_pass = 0;
        end

        wait(!tx);
        repeat (156) @(posedge clk);

        for (i = 0; i < DATA_WIDTH; i++) begin
            if (tx != data[i]) begin
                test_pass = 0;
                $display("Bit %0d FAIL: tx=%b expected=%b", i, tx, data[i]);
            end
            repeat (104) @(posedge clk);
        end

        wait(tx);

        if (test_pass) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

        wait(!busy);

    endtask

    initial begin
        test_uart_tx();
        $finish;
    end
endmodule