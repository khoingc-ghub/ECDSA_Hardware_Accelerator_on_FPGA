`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/09/2026 05:40:11 PM
// Design Name: 
// Module Name: tb
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




module tb;

    localparam int SCALAR_W = 256;
    localparam int DEPTH    = 16;

    // secp256r1 prime
    localparam logic [255:0] P_MOD =
        256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;

    // secp256r1 order
    localparam logic [255:0] ORDER_N =
        256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

    // Montgomery constants
    localparam logic [255:0] ONE_MONT =
        256'h0000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000010;

    localparam logic [255:0] A_MONT =
        256'hFFFFFFCF00000031000000000000000000000030FFFFFFFFFFFFFFFFFFFFFFCF;

    localparam logic [255:0] GX_MONT =
        256'h8905F76B53755C669FB732B7762251075BA95FC4FEDB60179E730D418A9143C1;

    localparam logic [255:0] GY_MONT =
        256'h571FF18A5885D8552E88688DD21F3258B4AB8E43A19E45CDDF25357CE95560A8;

    localparam logic [255:0] X2G_MONT =
        256'h6BB32E52DCF3A3A832205038D1490D9AA6AE3C0B433827D850046D410DDD64DF;

    localparam logic [255:0] Y2G_MONT =
        256'h8C577517A5B8A3AA9A8FB0E92042DBE152CD7CB7B236FF82F3648D361BEE1A57;

    logic clk;
    logic rst_n;
    logic start;
    logic [SCALAR_W-1:0] k_in;

    logic busy;
    logic done;
    logic [255:0] X_out, Y_out, Z_out;

    // DUT
    double_and_add #(
        .SCALAR_W (SCALAR_W),
        .DEPTH    (DEPTH)     
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .k_in  (k_in),
        .busy  (busy),
        .done  (done),
        .X_out (X_out),
        .Y_out (Y_out),
        .Z_out (Z_out)
    );

    // clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic run_case(
        input string        name,
        input logic [255:0] k_val
    );
        integer timeout;
        begin
            @(negedge clk);
            k_in  <= k_val;
            start <= 1'b1;

            @(negedge clk);
            start <= 1'b0;

            timeout = 0;
            while (done !== 1'b1) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 3000000) begin
                    $display("TIMEOUT at case %s", name);
                    $finish;
                end
            end

            @(negedge clk);
            $display("============================================================");
            $display("CASE : %s", name);
            $display("k    : %064h", k_val);
            $display("Xout : %064h", X_out);
            $display("Yout : %064h", Y_out);
            $display("Zout : %064h", Z_out);
            $display("============================================================");

            repeat (3) @(negedge clk);
        end
    endtask

    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        k_in  = '0;

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        run_case("k0"   , 256'd0);
        run_case("k1"   , 256'd1);
        run_case("k2"   , 256'd2);
        run_case("k3"   , 256'd3);
        run_case("k4"   , 256'd4);
        run_case("k5"   , 256'd5);
        run_case("k10"  , 256'd10);
        run_case("k_n_1", ORDER_N - 1'b1);
        run_case("k_n"  , ORDER_N);

        $display("TB finished.");
        $finish;
    end

endmodule