`timescale 1ns/1ps

module matrix_layer #(
    parameter N = 8,
    parameter INPUT_ROWS = 2,
    parameter INPUT_COLS = 2,
    parameter WEIGHT_COLS = 2,
    parameter ACC_WIDTH = 2*N + $clog2(INPUT_COLS),
    parameter OUTPUT_WIDTH = ACC_WIDTH + 1,
    parameter ROW_INDEX_WIDTH = (INPUT_ROWS > 1) ? $clog2(INPUT_ROWS) : 1,
    parameter COL_INDEX_WIDTH = (WEIGHT_COLS > 1) ? $clog2(WEIGHT_COLS) : 1
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
    localparam logic [COL_INDEX_WIDTH-1:0] LAST_COL =
    COL_INDEX_WIDTH'(WEIGHT_COLS - 1);

    logic signed [INPUT_COLS-1:0][N-1:0] dot_input;
    logic signed [INPUT_COLS-1:0][N-1:0] dot_weight;
    logic signed [ACC_WIDTH-1:0] dot_result;
    logic signed [ACC_WIDTH:0] bias_result;
    logic dot_start, dot_done;

    typedef enum logic [2:0] {
        IDLE,
        LAUNCH,
        WAIT,
        STORE,
        DONE
    } state_t;

    state_t state;
    state_t next_state;

    dot_product #(.N(N), .NUM_ELEMENTS(INPUT_COLS)) dut(.clk(clk), .rst(rst), .start(dot_start), .input_data(dot_input), .weight(dot_weight), .done(dot_done), .result(dot_result));

    always_ff @( posedge clk) begin
        if(rst) begin
            state <= IDLE;
            row_index <= 0;
            col_index <= 0;
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

        if(state == STORE) begin
            if(bias_result < 0) begin
                output_data[row_index][col_index] <= 0;
            end
            else begin
                output_data[row_index][col_index] <= bias_result;
            end

            if(col_index == LAST_COL) begin
                col_index <= 0;
                if (row_index == LAST_ROW) begin
                end
                else begin
                    row_index <= row_index + 1;
                end
            end
            else begin
                col_index <= col_index + 1;
            end
        end

    end

    always_comb begin

    for (int k = 0; k < INPUT_COLS; k++) begin
        dot_input[k] = input_data_reg[row_index][k];
        dot_weight[k] = weight_reg[k][col_index];
    end

    dot_start = 0;
    done = 0;
    busy = (state != IDLE && state != DONE);
    next_state = state;
    bias_result = $signed(dot_result) + $signed(bias_reg[col_index]);

    case (state)
        IDLE: begin
            if(start) begin
                next_state = LAUNCH;
            end
            else begin
                next_state = IDLE;
            end
         end
        LAUNCH: begin
            dot_start = 1;
            next_state = WAIT;
        end
        WAIT: begin
            dot_start = 0;

            if(dot_done) begin
                next_state = STORE;
            end
            else begin
                next_state = WAIT;
            end
        end
        STORE: begin
            if(col_index == LAST_COL) begin
                if (row_index == LAST_ROW) begin
                    next_state = DONE;
                end
                else begin
                    next_state = LAUNCH;
                end
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
