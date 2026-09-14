module multiplier_tb ();
    logic signed [7:0] a, b;
    logic signed [15:0] product;

    multiplier #(
        .N(8)
    ) dut(.a(a), .b(b), .product(product));

    task automatic tb_testing(
        logic signed [7:0] test_a, test_b,
        logic signed [15:0] test_expected
    );
        a = test_a;
        b = test_b;

        #1;

        $display("EXPECTED: %d", test_expected);
        $display("ACTUAL: %d", product);

        if (product == test_expected) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end
    endtask

    initial begin
        tb_testing(-5, 7, -35);
        tb_testing(7, 5, 35);
    end

endmodule