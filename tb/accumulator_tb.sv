module accumulator_tb();

    logic clk, rst;
    logic signed [15:0] product;
    logic signed [16:0] acc;
    logic signed [16:0] expected;

    always #5 clk = ~clk;

    task automatic test_acc(
        logic signed [15:0] test_product,
        logic signed [16:0] test_expected
    );

        product = test_product;

        @(posedge clk);
            #1;

            $display("Expected: %d", test_expected);
            $display("Actual: %d", acc);

            if (acc == test_expected) begin
                $display("PASS");
            end
            else begin
                $display("FAIL");
            end

    endtask

    initial begin
        clk = 0;
        rst = 1;
        product = 0;
        expected = 0;

        #6;
        $display("Expected: %d", expected);
        $display("Actual: %d", acc);

        if (acc == 0) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

        rst = 0;

        test_acc(6,6);
        test_acc(-3,3);
        test_acc(10,13);
        test_acc(-5,8);
    $finish;
    end

    accumulator #(.N(8)) dut(.clk(clk), .rst(rst), .product(product), .acc(acc));

endmodule