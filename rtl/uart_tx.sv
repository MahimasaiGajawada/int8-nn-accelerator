module uart_tx #(
    parameter DATA_WIDTH = 8,
    parameter CLKS_PER_BIT = 104
)(
    input  logic clk, rst,
    input  logic start,
    input  logic [DATA_WIDTH-1:0] data,

    output logic tx,
    output logic busy
);

    logic [$clog2(CLKS_PER_BIT)-1:0] counter;
    logic [$clog2(DATA_WIDTH)-1:0] bit_index;
    logic  [DATA_WIDTH-1:0] data_reg;

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP
     } state_t;

     state_t state;
     state_t next_state;

     assign busy = !(state == IDLE);

     always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            counter <= 0;
            bit_index <= 0;
            data_reg <= 0;
        end
        else begin
            state <= next_state;
            if (state == IDLE) begin
                counter <= 0;
                if (start) begin
                    data_reg <= data;
                    bit_index <= 0;
                end
            end
            else if (counter == CLKS_PER_BIT - 1) begin
                counter <= 0;
                if (state == DATA) begin
                    bit_index <= bit_index + 1;
                end
            end
            else begin
                counter <= counter + 1;
            end
        end
     end

     always_comb begin
        next_state = state;
        tx = 1;

        case(state)
            IDLE: begin
                if(start) begin
                    next_state = START;
                end
                else begin
                    next_state = IDLE;
                end
            end
            START: begin
                tx = 0;

                if (counter == CLKS_PER_BIT - 1) begin
                    next_state = DATA;
                end
                else begin
                    next_state = START;
                end
            end
            DATA: begin
                tx = data_reg[bit_index];
                if (counter == CLKS_PER_BIT - 1) begin
                    if (bit_index == $clog2(DATA_WIDTH)'(DATA_WIDTH-1)) begin
                        next_state = STOP;
                    end
                    else begin
                        next_state = DATA;
                    end
                end
                else begin
                    next_state = DATA;
                end
            end
            STOP: begin
                if (counter == CLKS_PER_BIT - 1) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = STOP;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
     end

endmodule