`timescale 1ns/1ps

module parallel_matrix_layer #(
    parameter N = 8,
    parameter INPUT_ROWS = 2,
    parameter INPUT_COLS = 2,
    parameter WEIGHT_COLS = 2,
    parameter ACC_WIDTH = 2*N + $clog2(INPUT_COLS),
    parameter OUTPUT_WIDTH = ACC_WIDTH + 1,
    parameter ROW_INDEX_WIDTH = (INPUT_ROWS > 1) ? $clog2(INPUT_ROWS) : 1,
    parameter COL_INDEX_WIDTH = (WEIGHT_COLS > 1) ? $clog2(WEIGHT_COLS) : 1,
    parameter PARALLEL_MACS = 2
) (
    input  logic clk,
    input  logic rst,
    input  logic start,

    input  logic signed [INPUT_ROWS-1:0][INPUT_COLS-1:0][N-1:0] input_data,
    input  logic signed [INPUT_COLS-1:0][WEIGHT_COLS-1:0][N-1:0] weight,
    input  logic signed [WEIGHT_COLS-1:0][ACC_WIDTH-1:0] bias,

    output logic busy, done,

    output logic signed [INPUT_ROWS-1:0][WEIGHT_COLS-1:0][OUTPUT_WIDTH-1:0] output_data
);

    logic signed [INPUT_ROWS-1:0][INPUT_COLS-1:0][N-1:0] input_data_reg;
    logic signed [INPUT_COLS-1:0][WEIGHT_COLS-1:0][N-1:0] weight_reg;
    logic signed [WEIGHT_COLS-1:0][ACC_WIDTH-1:0] bias_reg;

    logic [ROW_INDEX_WIDTH-1:0] row_index;
    logic [COL_INDEX_WIDTH-1:0] col_index;

    localparam logic [ROW_INDEX_WIDTH-1:0] LAST_ROW =
    ROW_INDEX_WIDTH'(INPUT_ROWS - 1);

    logic signed [PARALLEL_MACS-1:0][INPUT_COLS-1:0][N-1:0] dot_input;
    logic signed [PARALLEL_MACS-1:0][INPUT_COLS-1:0][N-1:0] dot_weight;
    logic signed [PARALLEL_MACS-1:0][ACC_WIDTH-1:0] dot_result;
    logic signed [PARALLEL_MACS-1:0][ACC_WIDTH:0] bias_result;

    logic [PARALLEL_MACS-1:0] dot_start,dot_done, engine_valid, engine_done;
    logic all_done;

    generate
        for (genvar e = 0; e < PARALLEL_MACS; e++) begin : GEN_DOT_PRODUCTS

            dot_product #(
                .N(N),
                .NUM_ELEMENTS(INPUT_COLS)
            ) dut (
                .clk(clk),
                .rst(rst),
                .start(dot_start[e]),
                .input_data(dot_input[e]),
                .weight(dot_weight[e]),
                .done(dot_done[e]),
                .result(dot_result[e])
            );

        end
    endgenerate

    typedef enum logic [2:0] {
        IDLE,
        LAUNCH,
        WAIT,
        STORE,
        DONE
    } state_t;

    state_t state;
    state_t next_state;

    always_ff @( posedge clk) begin
        if(rst) begin
            state <= IDLE;
            row_index <= 0;
            col_index <= 0;
            engine_done <= 0;
        end
        else begin
            state <= next_state;
        end

        if(state == IDLE && start) begin
           input_data_reg <= input_data;
           weight_reg <= weight;
           bias_reg <= bias;
           row_index <= 0;
           col_index <= 0;
        end

        if (state == WAIT) begin
            for (int e = 0; e < PARALLEL_MACS; e++) begin
                if (dot_done[e])
                    engine_done[e] <= 1;
            end
        end

        if (state == LAUNCH) begin
            engine_done <= 0;
        end

        if (state == STORE) begin
            for (int e = 0; e < PARALLEL_MACS; e++) begin
                if (engine_valid[e]) begin
                    if ($signed(bias_result[e]) < 0)
                        output_data[row_index][int'(col_index) + e] <= 0;
                    else
                        output_data[row_index][int'(col_index) + e] <= bias_result[e];
                end
            end

            if (int'(col_index) + PARALLEL_MACS >= WEIGHT_COLS) begin
                col_index <= 0;

                if (row_index != LAST_ROW)
                    row_index <= row_index + 1;
            end
            else begin
                col_index <= col_index + COL_INDEX_WIDTH'(PARALLEL_MACS);
            end
        end
    end

always_comb begin

    for (int e = 0; e < PARALLEL_MACS; e++) begin

        int current_col;
        current_col = int'(col_index) + e;

        if (current_col < WEIGHT_COLS) begin
            engine_valid[e] = 1;

            for (int k = 0; k < INPUT_COLS; k++) begin
                dot_input[e][k] = input_data_reg[row_index][k];
                dot_weight[e][k] = weight_reg[k][current_col];
            end

            bias_result[e] = $signed(dot_result[e]) +
                             $signed(bias_reg[current_col]);
        end

        else begin
            engine_valid[e] = 0;

            for (int k = 0; k < INPUT_COLS; k++) begin
                dot_input[e][k] = 0;
                dot_weight[e][k] = 0;
            end

            bias_result[e] = 0;
        end

    end

    dot_start = 0;
    done = 0;
    busy = (state != IDLE && state != DONE);
    next_state = state;
    all_done = 0;

    case (state)

        IDLE: begin
            if (start)
                next_state = LAUNCH;
            else
                next_state = IDLE;
        end

        LAUNCH: begin

            for (int e = 0; e < PARALLEL_MACS; e++) begin
                dot_start[e] = engine_valid[e];
            end

            next_state = WAIT;

        end

        WAIT: begin

            dot_start = 0;
            all_done = 1;

            for (int d = 0; d < PARALLEL_MACS; d++) begin
                if (engine_valid[d] && !engine_done[d])
                    all_done = 0;
            end

            if (all_done)
                next_state = STORE;
            else
                next_state = WAIT;

        end

        STORE: begin

            if (int'(col_index) + PARALLEL_MACS >= WEIGHT_COLS) begin

                if (row_index == LAST_ROW)
                    next_state = DONE;
                else
                    next_state = LAUNCH;

            end
            else begin
                next_state = LAUNCH;
            end

        end

        DONE: begin
            done = 1;
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end

    endcase

end
endmodule
