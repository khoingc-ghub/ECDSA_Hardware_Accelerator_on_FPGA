`timescale 1ns/1ps

module tb_knuth();

    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    reg [31:0] x;
    reg [31:0] y;
    wire [63:0] result;
    wire done;
    wire stage1_busy_tb;
    wire stage1_done_tb;

    // Instantiate the DUT
    knuth uut (
        .x(x),
        .y(y),
        .clk(clk),
        .rst(rst),
        .start(start),
        .result(result),
        .done(done)
    );

    assign stage1_busy_tb = uut.stage1_busy;
    assign stage1_done_tb = uut.stage1_done;
    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_mul;
        input [31:0] tx;
        input [31:0] ty;
        begin
            wait (stage1_busy_tb == 1'b0);
            @(posedge clk);
            x = tx;
            y = ty;
            start = 1;
            @(posedge clk);
            start = 0;
	    wait (stage1_busy_tb == 1'b1);
        end
    endtask

    // Stimulus
    initial begin
        // Initialize
        rst = 1;
        start = 0;
        x = 0;
        y = 0;
        #20;
        rst = 0;

        // Send test cases
                        // 15 * 12 = 180
        send_mul(32'd123456, 32'd654321);        // 123456 * 654321
	send_mul(32'd1500, 32'd1200);
        send_mul(32'hFFFFFFFF, 32'hFFFFFFFF);    // Max 32-bit * Max 32-bit
        send_mul(32'd0, 32'd999999);            // 0 * 999999 = 0
        
    end

    // Display results
    always @(posedge clk) begin
        if (done) begin
            $display("result: %d", result);
        end
    end
endmodule
