`timescale 1ns/1ps

module multiplier #(
    parameter N = 8
) (
    input logic signed [N-1:0] a, b,
    output logic signed [2*N-1:0] product
);

    assign product = a * b;

endmodule
