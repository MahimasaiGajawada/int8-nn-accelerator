`timescale 1ns/1ps

module parallel_matrix_layer_yosys #(
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
    input logic clk,
    input logic rst,
    input logic start,

    input logic signed [INPUT_ROWS*INPUT_COLS*N-1:0] input_data,
    input logic signed [INPUT_COLS*WEIGHT_COLS*N-1:0] weight,
    input logic signed [WEIGHT_COLS*ACC_WIDTH-1:0] bias,

    output logic busy,
    output logic done,

    output logic signed [INPUT_ROWS*WEIGHT_COLS*OUTPUT_WIDTH-1:0] output_data
);

    // ------------------------------------------------------------------------
    // Registered inputs
    // ------------------------------------------------------------------------

    logic signed [INPUT_ROWS*INPUT_COLS*N-1:0] input_data_reg;
    logic signed [INPUT_COLS*WEIGHT_COLS*N-1:0] weight_reg;
    logic signed [WEIGHT_COLS*ACC_WIDTH-1:0] bias_reg;

    // ------------------------------------------------------------------------
    // Matrix position
    // ------------------------------------------------------------------------

    logic [ROW_INDEX_WIDTH-1:0] row_index;
    logic [COL_INDEX_WIDTH-1:0] col_index;

    localparam logic [ROW_INDEX_WIDTH-1:0] LAST_ROW =
        ROW_INDEX_WIDTH'(INPUT_ROWS - 1);

    // ------------------------------------------------------------------------
    // Parallel dot-product engine signals
    //
    // Each engine gets one flattened INPUT_COLS*N vector.
    // ------------------------------------------------------------------------

    logic signed [PARALLEL_MACS*INPUT_COLS*N-1:0] dot_input;
    logic signed [PARALLEL_MACS*INPUT_COLS*N-1:0] dot_weight;

    logic signed [PARALLEL_MACS*ACC_WIDTH-1:0] dot_result;

    logic signed [PARALLEL_MACS*(ACC_WIDTH+1)-1:0] bias_result;

    logic [PARALLEL_MACS-1:0] dot_start;
    logic [PARALLEL_MACS-1:0] dot_done;
    logic [PARALLEL_MACS-1:0] engine_valid;
    logic [PARALLEL_MACS-1:0] engine_done;

    logic all_done;

    // ------------------------------------------------------------------------
    // Generate PARALLEL_MACS independent dot-product engines
    // ------------------------------------------------------------------------

    generate
        for (genvar e = 0; e < PARALLEL_MACS; e++) begin : GEN_DOT_PRODUCTS

            dot_product_yosys #(
                .N(N),
                .NUM_ELEMENTS(INPUT_COLS)
            ) dut (
                .clk(clk),
                .rst(rst),
                .start(dot_start[e]),
                .input_data(
                    dot_input[e*INPUT_COLS*N +: INPUT_COLS*N]
                ),
                .weight(
                    dot_weight[e*INPUT_COLS*N +: INPUT_COLS*N]
                ),
                .done(dot_done[e]),
                .result(
                    dot_result[e*ACC_WIDTH +: ACC_WIDTH]
                )
            );

        end
    endgenerate

    // ------------------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------------------

    typedef enum logic [2:0] {
        IDLE,
        LAUNCH,
        WAIT,
        STORE,
        DONE
    } state_t;

    state_t state;
    state_t next_state;

    // ------------------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin
            state <= IDLE;
            row_index <= 0;
            col_index <= 0;
            engine_done <= 0;
        end
        else begin
            state <= next_state;
        end

        // Latch a completely new matrix operation
        if (state == IDLE && start) begin
            input_data_reg <= input_data;
            weight_reg <= weight;
            bias_reg <= bias;

            row_index <= 0;
            col_index <= 0;
        end

        // Record completed parallel engines
        if (state == WAIT) begin
            for (int e = 0; e < PARALLEL_MACS; e++) begin
                if (dot_done[e])
                    engine_done[e] <= 1;
            end
        end

        // Clear completion flags before launching a new batch
        if (state == LAUNCH) begin
            engine_done <= 0;
        end

        // Store the completed outputs
        if (state == STORE) begin

            for (int e = 0; e < PARALLEL_MACS; e++) begin

                if (engine_valid[e]) begin

                    if ($signed(
                        bias_result[e*(ACC_WIDTH+1) +: ACC_WIDTH+1]
                    ) < 0) begin

                        output_data[
                            (row_index * WEIGHT_COLS +
                             (col_index + e)) * OUTPUT_WIDTH
                            +: OUTPUT_WIDTH
                        ] <= 0;

                    end
                    else begin

                        output_data[
                            (row_index * WEIGHT_COLS +
                             (col_index + e)) * OUTPUT_WIDTH
                            +: OUTPUT_WIDTH
                        ] <= bias_result[
                            e*(ACC_WIDTH+1) +: ACC_WIDTH+1
                        ];

                    end
                end
            end

            // Move to the next group of output columns
            if (col_index + PARALLEL_MACS >= WEIGHT_COLS) begin

                col_index <= 0;

                if (row_index != LAST_ROW)
                    row_index <= row_index + 1;

            end
            else begin
                col_index <= col_index + PARALLEL_MACS;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Combinational datapath + FSM control
    // ------------------------------------------------------------------------

    always_comb begin

        // ------------------------------------------------------------
        // Construct inputs for each parallel dot-product engine
        // ------------------------------------------------------------

        for (int e = 0; e < PARALLEL_MACS; e++) begin

            int current_col;

            current_col = col_index + e;

            if (current_col < WEIGHT_COLS) begin

                engine_valid[e] = 1;

                // Build input vector for this engine
                for (int k = 0; k < INPUT_COLS; k++) begin

                    dot_input[
                        e*INPUT_COLS*N + k*N +: N
                    ] =
                        input_data_reg[
                            (row_index * INPUT_COLS + k)*N +: N
                        ];

                    dot_weight[
                        e*INPUT_COLS*N + k*N +: N
                    ] =
                        weight_reg[
                            (k * WEIGHT_COLS + current_col)*N +: N
                        ];

                end

                // Dot product + bias
                bias_result[
                    e*(ACC_WIDTH+1) +: ACC_WIDTH+1
                ] =
                    $signed(
                        dot_result[
                            e*ACC_WIDTH +: ACC_WIDTH
                        ]
                    )
                    +
                    $signed(
                        bias_reg[
                            current_col*ACC_WIDTH +: ACC_WIDTH
                        ]
                    );

            end
            else begin

                engine_valid[e] = 0;

                // Prevent unused engines from seeing stale data
                for (int k = 0; k < INPUT_COLS; k++) begin

                    dot_input[
                        e*INPUT_COLS*N + k*N +: N
                    ] = 0;

                    dot_weight[
                        e*INPUT_COLS*N + k*N +: N
                    ] = 0;

                end

                bias_result[
                    e*(ACC_WIDTH+1) +: ACC_WIDTH+1
                ] = 0;

            end
        end

        // ------------------------------------------------------------
        // Default control signals
        // ------------------------------------------------------------

        dot_start = 0;

        done = 0;

        busy = (state != IDLE && state != DONE);

        next_state = state;

        all_done = 0;

        // ------------------------------------------------------------
        // FSM
        // ------------------------------------------------------------

        case (state)

            IDLE: begin

                if (start)
                    next_state = LAUNCH;
                else
                    next_state = IDLE;

            end

            LAUNCH: begin

                // Launch all valid parallel engines simultaneously
                for (int e = 0; e < PARALLEL_MACS; e++) begin
                    dot_start[e] = engine_valid[e];
                end

                next_state = WAIT;

            end

            WAIT: begin

                dot_start = 0;

                // Assume completion until an active engine says otherwise
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

                // Determine whether another group of columns remains
                if (col_index + PARALLEL_MACS >= WEIGHT_COLS) begin

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