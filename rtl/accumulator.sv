`timescale 1ns/1ps

module accumulator #(
    parameter N = 8
) (
    input logic clk, rst,
    input signed [2*N-1:0] product,
    output signed [2*N:0] acc
);

    always_ff @( posedge clk ) begin
        if(rst) begin
            acc <= 0;
        end
        else begin
            acc <= acc + product;
        end
    end
endmodule
