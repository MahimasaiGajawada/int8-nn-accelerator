module mac_unit #(
    parameter N = 8
) (
    input logic clk, rst,
    input signed [N-1:0] input_data, weight,
    output signed [2*N:0] acc
);
    logic signed [2*N-1:0] product;

    multiplier #(.N(N)) dut(.a(input_data), .b(weight), .product(product));

    accumulator #(.N(N)) dut_acc(.clk(clk), .rst(rst), .product(product), .acc(acc));

endmodule