module mac_unit_tb();

    logic clk, rst;
    logic signed [7:0] input_data, weight;
    logic signed [16:0] expected, acc;

    mac_unit #(.N(8)) dut(.clk(clk), .rst(rst), .input_data(input_data), .weight(weight), .acc(acc));

    always #5 clk = ~clk;

    task automatic test_mac_unit(
        logic signed [7:0] test_input_data, test_weight,
        logic signed [16:0] test_expected
    );
        input_data = test_input_data;
        weight = test_weight;
        expected = test_expected;

        @(posedge clk);
        #1;

        $display("EXPECTED: %d", expected);
        $display("ACTUAL: %d", acc);

        if (expected == acc) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

    endtask

    initial begin
        clk = 0;
        rst = 1;
        input_data = 0;
        weight = 0;
        expected = 0;

        @(posedge clk);

        #1;

        if(acc == 0) begin
            $display(" RESET PASSED");
        end
        else begin
            $display("RESET FAILED");
        end

        rst=0;

        @(posedge clk);
        #1;

        test_mac_unit(3, 5, 15);
        test_mac_unit(2, 7, 29);
        test_mac_unit(-1, 4, 25);
    $finish;
    end

endmodule