`timescale 1ns/1ps

module dot_product #(
    parameter N = 8,
    parameter NUM_ELEMENTS = 4,
    parameter ACC_WIDTH = 2*N + $clog2(NUM_ELEMENTS)
) (
    input logic clk, rst, start,
    input signed [NUM_ELEMENTS*N-1:0] input_data, weight,
    output logic done,
    output logic signed [ACC_WIDTH-1:0] result
);

    localparam PRODUCT_WIDTH = 2*N;
    localparam COUNT_WIDTH = $clog2(NUM_ELEMENTS);

    logic signed [NUM_ELEMENTS*N-1:0]input_reg, weight_reg;
    logic signed [ACC_WIDTH-1:0] acc;
    logic [COUNT_WIDTH-1:0] count;
    logic signed [PRODUCT_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0] extended_product;

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DONE
    } state_t;

    state_t state;
    state_t next_state;

    multiplier #(.N(N)) compute_multiplier(.a(input_reg[count*N +: N]), .b(weight_reg[count*N +: N]), .product(product));

    assign done = (state == DONE);
    assign extended_product = ACC_WIDTH'(product);

    always_ff @( posedge clk ) begin
        if(rst) begin
            state <= IDLE;
            acc <= 0;
            count <= 0;
            result <= 0;
        end
        else begin
            state <= next_state;
        end

        if (state == IDLE && start) begin
            input_reg <= input_data;
            weight_reg <= weight;
            acc <= 0;
            count <= 0;
        end

        if (state == COMPUTE) begin
            acc <= acc + extended_product;

            if (count == COUNT_WIDTH'(NUM_ELEMENTS - 1)) begin
                result <= acc + extended_product;
            end
            else begin
                count <= count + 1;
            end
        end
    end

    always_comb begin

        next_state = state;

        case (state)
            IDLE: begin
                if(start) begin
                next_state = COMPUTE;
            end
            else begin
                next_state = IDLE;
            end
            end
            COMPUTE: begin
                if (count == COUNT_WIDTH'(NUM_ELEMENTS - 1)) begin
                next_state = DONE;
            end
            else begin
                next_state = COMPUTE;
            end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
