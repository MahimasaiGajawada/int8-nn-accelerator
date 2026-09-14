module dot_product_tb();

    logic clk, rst, start, done;
    logic signed [31:0] input_data, weight;
    logic signed [17:0] result;

    dot_product #(.N(8)) dut(
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_data(input_data),
        .weight(weight),
        .done(done),
        .result(result)
    );

    always #5 clk = ~clk;

    task automatic test_dot_product(
        input signed [31:0] test_input_data,
        input signed [31:0] test_weight,
        input signed [17:0] expected
    );

        input_data = test_input_data;
        weight = test_weight;

        start = 1;

        @(posedge clk);
        #1;

        start = 0;

        wait(done);
        #1;

        $display("EXPECTED: %d", expected);
        $display("ACTUAL: %d", result);

        if (expected == result) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

        wait(!done);
    endtask

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        input_data = 0;
        weight = 0;

        @(posedge clk);
        #1;
        rst = 0;

        test_dot_product(
            {8'sd4, -8'sd1, 8'sd3, 8'sd2},
            {8'sd3, 8'sd7, -8'sd2, 8'sd5},
            18'sd9
        );

        test_dot_product(
            {8'sd4, 8'sd3, 8'sd2, 8'sd1},
            {8'sd8, 8'sd7, 8'sd6, 8'sd5},
            18'sd70
        );

        test_dot_product(
            {-8'sd1, -8'sd4, -8'sd3, -8'sd2},
            {8'sd7, -8'sd3, -8'sd2, 8'sd5},
            18'sd1
        );

        $finish;
    end

endmodule