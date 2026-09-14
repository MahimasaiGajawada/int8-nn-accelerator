module top_tb();

    logic clk, rst, done, tx;
    logic signed [1:0][1:0][7:0] input_data;
    logic signed [1:0][2:0][7:0] weight;
    logic signed [2:0][16:0] bias;

    logic [7:0] received;

    always #5 clk = ~clk;

    assign input_data[0][0] = 8'sd1;
    assign input_data[0][1] = 8'sd2;
    assign input_data[1][0] = 8'sd3;
    assign input_data[1][1] = 8'sd4;

    assign weight[0][0] = 8'sd1;
    assign weight[0][1] = 8'sd0;
    assign weight[0][2] = 8'sd2;
    assign weight[1][0] = 8'sd0;
    assign weight[1][1] = 8'sd1;
    assign weight[1][2] = 8'sd3;

    assign bias = {17'sd0, 17'sd0, 17'sd0};

    top dut (.clk(clk), .rst(rst), .done(done), .tx(tx));

    task automatic test_top(
        output logic [7:0] received
    );
        int i;

        @(negedge tx);

        repeat (52) @(posedge clk);

        for (i = 0; i < 8; i++) begin
            repeat (104) @(posedge clk);
            received[i] = tx;
        end


        repeat (104) @(posedge clk);

        if (tx != 1'b1) begin
            $display("ERROR: UART stop bit incorrect");
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;

        #20;

        rst = 0;

        test_top(received);

        $display("Received: %0d", received);

        test_top(received);

        $display("Received: %0d", received);

        for(int i = 0; i < 7; i++) begin
            if (received != 8'di) begin
                $display("ERROR: expected 1, got %0d", received);
            end
            else begin
                $display("UART BYTE i PASS: %0d", received);
            end
        end

    end

endmodule