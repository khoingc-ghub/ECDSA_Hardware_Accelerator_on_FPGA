`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 07:43:48 PM
// Design Name: 
// Module Name: tb_hmac
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

module tb_hmac;

    logic clk;
    logic rst_n;

    logic start;
    logic busy;
    logic done;

    logic [255:0] key;
    logic [255:0] msg;
    logic [255:0] tag;

    integer cycle_cnt;
    integer start_cyc;
    integer done_cyc;

    localparam logic [255:0] TEST_KEY =
        256'h0000000000000000000000000000000000000000000000000000000000000000;

    localparam logic [255:0] TEST_MSG =
        256'h0101010101010101010101010101010101010101010101010101010101010101;

    localparam logic [255:0] TEST_TAG =
        256'h80A09DE3BFE30DA90116E588ADE2F812D49B55625BE8B4ABBFF775FA5A5A74E9;

    //=====//
    // dut //
    //=====//
    hmac_sha256_msg256 dut (
        .clk_i    (clk),
        .rst_ni   (rst_n),

        .start_i  (start),
        .key_i    (key),
        .msg_i    (msg),

        .busy_o   (busy),
        .done_o   (done),
        .tag_o    (tag)
    );

    //=======//
    // clock //
    //=======//
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    //===============//
    // cycle counter //
    //===============//
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
        end
        else begin
            cycle_cnt <= cycle_cnt + 1;
        end
    end

    //======//
    // main //
    //======//
    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        key   = '0;
        msg   = '0;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (10) @(negedge clk);

        key = TEST_KEY;
        msg = TEST_MSG;

        @(negedge clk);
        start     = 1'b1;
        start_cyc = cycle_cnt;

        @(negedge clk);
        start = 1'b0;

        wait (done == 1'b1);
        done_cyc = cycle_cnt;

        @(negedge clk);

        $display("============================================================");
        $display("HMAC-SHA256 msg256 test");
        $display("tag    = %064h", tag);
        $display("expect = %064h", TEST_TAG);
        $display("cycles = %0d", done_cyc - start_cyc);

        if (tag === TEST_TAG) begin
            $display("[PASS] HMAC-SHA256 msg256");
        end
        else begin
            $display("[FAIL] HMAC-SHA256 msg256");
        end

        $display("============================================================");

        repeat (10) @(negedge clk);
        $finish;
    end

endmodule
