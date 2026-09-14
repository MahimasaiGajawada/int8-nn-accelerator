module top_yosys #(
    parameter N = 8,
    parameter INPUT_ROWS = 2,
    parameter INPUT_COLS = 2,
    parameter WEIGHT_COLS = 3,
    parameter ACC_WIDTH = 2*N + $clog2(INPUT_COLS),
    parameter OUTPUT_WIDTH = ACC_WIDTH + 1
) (
    input logic clk, rst,
    output logic done,
    input logic signed [INPUT_ROWS * INPUT_COLS * N - 1:0] input_data,
    input logic signed [INPUT_COLS * WEIGHT_COLS * N - 1:0] weight,
    input logic signed [WEIGHT_COLS * ACC_WIDTH - 1:0] bias,

    output logic signed [INPUT_ROWS * WEIGHT_COLS * OUTPUT_WIDTH - 1:0] result
);

    logic start, busy;
    logic accelerator_done;


    matrix_layer_yosys #(
    .N(N),
    .INPUT_ROWS(INPUT_ROWS),
    .INPUT_COLS(INPUT_COLS),
    .WEIGHT_COLS(WEIGHT_COLS)
    ) dut (
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

    typedef enum logic [2:0] {
        IDLE,
        START,
        WAIT,
        DONE
     } state_t;

    state_t state;
    state_t next_state;

    always_ff @( posedge clk ) begin
        if (rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        start = 0;
        done = 0;

        case(state)
            IDLE: begin
                next_state = START;
            end
            START: begin
                start = 1;
                next_state = WAIT;
            end
            WAIT: begin
                if (accelerator_done && !busy) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = DONE;
                done = 1;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end



endmodule
