`timescale 1ns/1ps

module fpga_top_yosys #(
    parameter N = 8,
    parameter INPUT_ROWS = 2,
    parameter INPUT_COLS = 2,
    parameter WEIGHT_COLS = 3,
    parameter ACC_WIDTH = 2*N + $clog2(INPUT_COLS),
    parameter OUTPUT_WIDTH = ACC_WIDTH + 1
) (
    input  logic clk,
    input logic rst,
    output logic done,
    output logic tx
);

    logic start;
    logic busy;
    logic accelerator_done;

    logic signed [INPUT_ROWS*INPUT_COLS*N-1:0] input_data;
    logic signed [INPUT_COLS*WEIGHT_COLS*N-1:0] weight;
    logic signed [WEIGHT_COLS*ACC_WIDTH-1:0] bias;

    logic signed [INPUT_ROWS*WEIGHT_COLS*OUTPUT_WIDTH-1:0] result;

    logic uart_start;
    logic uart_busy;
    logic [7:0] uart_data;
    logic [2:0] result_index;

    // Fixed demonstration inputs:
    //
    // X = [[1, 2],
    //      [3, 4]]
    //
    // W = [[1, 0, 2],
    //      [0, 1, 3]]
    //
    // B = [0, 0, 0]

    assign input_data = {
        8'sd4, 8'sd3,
        8'sd2, 8'sd1
    };

    assign weight = {
        8'sd3, 8'sd1, 8'sd0,
        8'sd2, 8'sd0, 8'sd1
    };

    assign bias = {
        17'sd0,
        17'sd0,
        17'sd0
    };

    matrix_layer_yosys #(
        .N(N),
        .INPUT_ROWS(INPUT_ROWS),
        .INPUT_COLS(INPUT_COLS),
        .WEIGHT_COLS(WEIGHT_COLS)
    ) accelerator (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_data(input_data),
        .weight(weight),
        .bias(bias),
        .busy(busy),
        .done(accelerator_done),
        .output_data(result)
    );

    uart_tx #(
        .DATA_WIDTH(8),
        .CLKS_PER_BIT(104)
    ) uart (
        .clk(clk),
        .rst(rst),
        .start(uart_start),
        .data(uart_data),
        .tx(tx),
        .busy(uart_busy)
    );

    typedef enum logic [2:0] {
        IDLE,
        START_ACCEL,
        WAIT_ACCEL,
        SEND,
        WAIT_UART,
        DONE
    } state_t;

    state_t state;
    state_t next_state;

    always_comb begin
        case (result_index)
            0: uart_data = result[0*OUTPUT_WIDTH +: 8];
            1: uart_data = result[1*OUTPUT_WIDTH +: 8];
            2: uart_data = result[2*OUTPUT_WIDTH +: 8];
            3: uart_data = result[3*OUTPUT_WIDTH +: 8];
            4: uart_data = result[4*OUTPUT_WIDTH +: 8];
            5: uart_data = result[5*OUTPUT_WIDTH +: 8];
            default: uart_data = 0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            result_index <= 0;
        end
        else begin
            state <= next_state;

            if (state == WAIT_UART &&
                !uart_busy &&
                result_index < 5) begin
                result_index <= result_index + 1;
            end
        end
    end

    always_comb begin
        next_state = state;
        start = 0;
        uart_start = 0;
        done = 0;

        case (state)

            IDLE: begin
                next_state = START_ACCEL;
            end

            START_ACCEL: begin
                start = 1;
                next_state = WAIT_ACCEL;
            end

            WAIT_ACCEL: begin
                if (accelerator_done && !busy)
                    next_state = SEND;
            end

            SEND: begin
                uart_start = 1;
                next_state = WAIT_UART;
            end

            WAIT_UART: begin
                if (!uart_busy) begin
                    if (result_index == 5)
                        next_state = DONE;
                    else
                        next_state = SEND;
                end
            end

            DONE: begin
                done = 1;
                next_state = DONE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

endmodule