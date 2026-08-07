`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 05:59:16 PM
// Design Name: 
// Module Name: tb_sha256_one_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module tb_sha256_one_block;

    logic clk;
    logic rst_n;

    logic start;
    logic busy;
    logic done;

    logic [511:0] block;
    logic [255:0] digest;

    localparam logic [511:0] ABC_BLOCK =
        512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;

    localparam logic [255:0] ABC_DIGEST =
        256'hBA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD;

    //=====//
    // dut //
    //=====//
    sha256_one_block dut (
        .clk_i     (clk),
        .rst_ni    (rst_n),

        .start_i   (start),
        .block_i   (block),

        .busy_o    (busy),
        .done_o    (done),
        .digest_o  (digest)
    );

    //=======//
    // clock //
    //=======//
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    //======//
    // main //
    //======//
    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        block = '0;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (10) @(negedge clk);

        block = ABC_BLOCK;

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        wait (done == 1'b1);
        @(negedge clk);

        $display("============================================================");
        $display("SHA256 abc test");
        $display("digest = %064h", digest);
        $display("expect = %064h", ABC_DIGEST);

        if (digest === ABC_DIGEST) begin
            $display("[PASS] SHA256 abc");
        end
        else begin
            $display("[FAIL] SHA256 abc");
        end

        $display("============================================================");

        repeat (10) @(negedge clk);
        $finish;
    end

endmodule
