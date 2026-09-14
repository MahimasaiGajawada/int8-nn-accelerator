`timescale 1ns/1ps

module parallel_matrix_layer_odd_tb();

    initial begin
        $dumpfile("parallel_matrix_layer_odd.vcd");
        $dumpvars(0, parallel_matrix_layer_odd_tb);
    end

    logic clk, rst, start, busy, done;

    logic signed [1:0][1:0][7:0] input_data;
    logic signed [1:0][2:0][7:0] weight;

    logic signed [2:0][16:0] bias;

    logic signed [1:0][2:0][17:0] output_data;

    time start_time;
    time done_time;
    longint unsigned latency_cycles;

    parallel_matrix_layer #(
        .N(8),
        .INPUT_ROWS(2),
        .INPUT_COLS(2),
        .WEIGHT_COLS(3),
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


    task automatic test_parallel_matrix_layer_odd(

        input logic signed [7:0] in00,
        input logic signed [7:0] in01,
        input logic signed [7:0] in10,
        input logic signed [7:0] in11,

        input logic signed [7:0] w00,
        input logic signed [7:0] w01,
        input logic signed [7:0] w02,

        input logic signed [7:0] w10,
        input logic signed [7:0] w11,
        input logic signed [7:0] w12,

        input logic signed [16:0] b0,
        input logic signed [16:0] b1,
        input logic signed [16:0] b2,

        input logic signed [17:0] expected00,
        input logic signed [17:0] expected01,
        input logic signed [17:0] expected02,

        input logic signed [17:0] expected10,
        input logic signed [17:0] expected11,
        input logic signed [17:0] expected12
    );

        // -------------------------
        // Input matrix
        // -------------------------
        input_data[0][0] = in00;
        input_data[0][1] = in01;

        input_data[1][0] = in10;
        input_data[1][1] = in11;


        // -------------------------
        // Weight matrix
        // -------------------------
        weight[0][0] = w00;
        weight[0][1] = w01;
        weight[0][2] = w02;

        weight[1][0] = w10;
        weight[1][1] = w11;
        weight[1][2] = w12;


        // -------------------------
        // Bias
        // -------------------------
        bias[0] = b0;
        bias[1] = b1;
        bias[2] = b2;


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


        // -------------------------
        // Wait for completion
        // -------------------------
        wait(done);

        done_time = $time;

        latency_cycles = (done_time - start_time) / 10;

        $display("Latency: %0d cycles", latency_cycles);

        #1;

        $display("After computation: busy=%b done=%b", busy, done);


        // -------------------------
        // Display output
        // -------------------------
        $display("Output:");

        $display("[%0d %0d %0d]",
            output_data[0][0],
            output_data[0][1],
            output_data[0][2]
        );

        $display("[%0d %0d %0d]",
            output_data[1][0],
            output_data[1][1],
            output_data[1][2]
        );


        // -------------------------
        // Check output
        // -------------------------
        if (
            output_data[0][0] == expected00 &&
            output_data[0][1] == expected01 &&
            output_data[0][2] == expected02 &&

            output_data[1][0] == expected10 &&
            output_data[1][1] == expected11 &&
            output_data[1][2] == expected12
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


        // ============================================================
        // TEST 1: Basic 2x2 * 2x3 matrix multiplication
        //
        // X =
        // [1 2]
        // [3 4]
        //
        // W =
        // [5  6  9]
        // [7  8 10]
        //
        // B = [1 2 3]
        //
        // Expected:
        //
        // [1*5 + 2*7 + 1,  1*6 + 2*8 + 2,  1*9 + 2*10 + 3]
        // [3*5 + 4*7 + 1,  3*6 + 4*8 + 2,  3*9 + 4*10 + 3]
        //
        // =
        // [20 24 32]
        // [44 52 70]
        // ============================================================

        test_parallel_matrix_layer_odd(
            1, 2,
            3, 4,

            5, 6, 9,
            7, 8, 10,

            1, 2, 3,

            20, 24, 32,
            44, 52, 70
        );


        // ============================================================
        // TEST 2: Negative values + ReLU
        //
        // This checks that negative outputs become zero.
        //
        // X =
        // [1  -2]
        // [3  -4]
        //
        // W =
        // [5  -6  -9]
        // [-7  8  -10]
        //
        // B = [1 2 3]
        //
        // Expected after ReLU:
        //
        // [20 0 14]
        // [44 0 16]
        // ============================================================

        test_parallel_matrix_layer_odd(
            1, -2,
            3, -4,

            5, -6, -9,
            -7, 8, -10,

            1, 2, 3,

            20, 0, 14,
            44, 0, 16
        );


        // ============================================================
        // TEST 3: Third output column is the only active MAC
        //
        // This is the important odd-parallelism test.
        //
        // PARALLEL_MACS = 2
        // WEIGHT_COLS   = 3
        //
        // First batch:
        //   engine 0 -> column 0
        //   engine 1 -> column 1
        //
        // Second batch:
        //   engine 0 -> column 2
        //   engine 1 -> INVALID
        //
        // X =
        // [1 0]
        // [0 1]
        //
        // W =
        // [1 2 3]
        // [4 5 6]
        //
        // B = [10 20 30]
        //
        // Expected:
        //
        // [11 22 33]
        // [14 25 36]
        // ============================================================

        test_parallel_matrix_layer_odd(
            1, 0,
            0, 1,

            1, 2, 3,
            4, 5, 6,

            10, 20, 30,

            11, 22, 33,
            14, 25, 36
        );


        // ============================================================
        // TEST 4: Negative result specifically in third column
        //
        // This makes sure the odd final batch still handles ReLU.
        //
        // X =
        // [1  2]
        // [3  4]
        //
        // W =
        // [1  2  -5]
        // [1  2  -6]
        //
        // B = [0 0 1]
        //
        // Expected:
        //
        // [3  6  0]
        // [7 14  0]
        //
        // The third column is calculated by the final single
        // valid engine and should be clamped by ReLU.
        // ============================================================

        test_parallel_matrix_layer_odd(
            1, 2,
            3, 4,

            1, 2, -5,
            1, 2, -6,

            0, 0, 1,

            3, 6, 0,
            7, 14, 0
        );


        $finish;

    end

endmodule