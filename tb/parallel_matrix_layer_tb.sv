`timescale 1ns/1ps

module parallel_matrix_layer_tb();

    initial begin
        $dumpfile("parallel_matrix_layer.vcd");
        $dumpvars(0, parallel_matrix_layer_tb);
    end

    logic clk, rst, start, busy, done;

    logic signed [1:0][1:0][7:0] input_data;
    logic signed [1:0][1:0][7:0] weight;

    logic signed [1:0][16:0] bias;

    logic signed [1:0][1:0][17:0] output_data;

    time start_time;
    time done_time;
    longint unsigned latency_cycles;

    parallel_matrix_layer #(
        .N(8),
        .INPUT_ROWS(2),
        .INPUT_COLS(2),
        .WEIGHT_COLS(2),
        .PARALLEL_MACS(2)
    ) dut(
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_data(input_data),
        .weight(weight),
        .bias(bias),
        .busy(busy),
        .done(done),
        .output_data(output_data)
    );
    always #5 clk <= ~clk;

    task automatic test_parallel_matrix_layer(
        input logic signed [7:0] in00,
        input logic signed [7:0] in01,
        input logic signed [7:0] in10,
        input logic signed [7:0] in11,
        input logic signed [7:0] w00,
        input logic signed [7:0] w01,
        input logic signed [7:0] w10,
        input logic signed [7:0] w11,
        input logic signed [16:0] b0,
        input logic signed [16:0] b1,
        input logic signed [17:0] expected00,
        input logic signed [17:0] expected01,
        input logic signed [17:0] expected10,
        input logic signed [17:0] expected11
    );
        input_data[0][0] = in00;
        input_data[0][1] = in01;
        input_data[1][0] = in10;
        input_data[1][1] = in11;

        weight[0][0] = w00;
        weight[0][1] = w01;
        weight[1][0] = w10;
        weight[1][1] = w11;

        bias[0] = b0;
        bias[1] = b1;

        latency_cycles = 0;
        start = 1;

        @(posedge clk);
        start_time = $time;
        #1;

        start = 0;

        $display("After start: busy=%b done=%b", busy, done);

        if (!busy) begin
            $display("FAIL: busy should be high during computation");
        end

        wait(done);
        done_time = $time;
        latency_cycles = (done_time - start_time) / 10;

        $display("Latency: %0d cycles", latency_cycles);
        #1;

        $display("After computation: busy=%b done=%b", busy, done);

        $display("Output:");
        $display("[%0d %0d]", output_data[0][0], output_data[0][1]);
        $display("[%0d %0d]", output_data[1][0], output_data[1][1]);

        if (output_data[0][0] == expected00 &&
            output_data[0][1] == expected01 &&
            output_data[1][0] == expected10 &&
            output_data[1][1] == expected11
        ) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

        @(posedge clk);

    endtask

    initial begin
    clk = 0;
    rst = 1;
    start = 0;

    #10;
    rst = 0;

    test_parallel_matrix_layer(
        1, 2, 3, 4,
        5, 6, 7, 8,
        1, 2,
        20, 24, 44, 52
    );

    test_parallel_matrix_layer(
        1, -2, 3, -4,
        5, -6, -7, 8,
        1, 2,
        20, 0, 44, 0
    );

    test_parallel_matrix_layer(
        -5, 2, 1, -3,
        4, 6, -7, 2,
        1, 2,
        0, 0, 26, 2
    );

    test_parallel_matrix_layer(
        1, 0, 0, 1,
        1, 2, 3, 4,
        10, 20,
        11, 22, 13, 24
    );
    $finish;
end

endmodule
