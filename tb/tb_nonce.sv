`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/31/2026 11:24:38 AM
// Design Name: 
// Module Name: tb_nonce
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

module tb_nonce;

    logic clk;
    logic rst_n;

    logic start;
    logic busy;
    logic done;

    logic [255:0] d;
    logic [255:0] e;
    logic [255:0] n;
    logic [255:0] k;

    integer cycle_cnt;

    localparam logic [255:0] N_R1 =
        256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

    localparam logic [255:0] N_K1 =
        256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    localparam logic [255:0] TEST_D =
        256'h0202020202020202020202020202020202020202020202020202020202020202;

    localparam logic [255:0] TEST_E_SMALL =
        256'h0303030303030303030303030303030303030303030303030303030303030303;

    localparam logic [255:0] TEST_E_HIGH =
        256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    localparam logic [255:0] EXP_K_SMALL =
        256'h4C215942DB8C8516978B559DFC466372EF02B39188D886E01166AC12B590BB5A;

    localparam logic [255:0] EXP_K_HIGH_R1 =
        256'h867A18E4F6EF4CFE18090652584206A32F57EF87901C86401AEA0255E1566115;

    localparam logic [255:0] EXP_K_HIGH_K1 =
        256'hF1A460E31A9541E65F613CDF0354BC942C5B020FB7FC63E609A6861172F551E7;

    //=====//
    // dut //
    //=====//
    drbg_nonce dut (
        .clk_i   (clk),
        .rst_ni  (rst_n),

        .start_i (start),

        .d_i     (d),
        .e_i     (e),
        .n_i     (n),

        .busy_o  (busy),
        .done_o  (done),
        .k_o     (k)
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

    //==========//
    // run case //
    //==========//
    task automatic run_case (
        input string        name,
        input logic [255:0] d_val,
        input logic [255:0] e_val,
        input logic [255:0] n_val,
        input logic [255:0] exp_k
    );
        integer start_cyc;
        integer done_cyc;
        integer timeout;

        begin
            @(negedge clk);

            d     <= d_val;
            e     <= e_val;
            n     <= n_val;
            start <= 1'b1;

            start_cyc = cycle_cnt;

            @(negedge clk);
            start <= 1'b0;

            timeout = 0;

            while (done !== 1'b1) begin
                @(posedge clk);
                timeout++;

                if (timeout > 20000) begin
                    $display("[TIMEOUT] %s", name);
                    $finish;
                end
            end

            done_cyc = cycle_cnt;

            @(negedge clk);

            $display("============================================================");
            $display("CASE   : %s", name);
            $display("d      : %064h", d_val);
            $display("e      : %064h", e_val);
            $display("n      : %064h", n_val);
            $display("k      : %064h", k);
            $display("expect : %064h", exp_k);
            $display("cycles : %0d", done_cyc - start_cyc);

            if (k === exp_k) begin
                $display("[PASS] %s", name);
            end
            else begin
                $display("[FAIL] %s", name);
            end

            $display("============================================================");

            repeat (5) @(negedge clk);
        end
    endtask

    //======//
    // main //
    //======//
    initial begin
        rst_n = 1'b0;
        start = 1'b0;

        d = '0;
        e = '0;
        n = '0;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (10) @(negedge clk);

        run_case(
            "R1_e_small",
            TEST_D,
            TEST_E_SMALL,
            N_R1,
            EXP_K_SMALL
        );

        run_case(
            "K1_e_small",
            TEST_D,
            TEST_E_SMALL,
            N_K1,
            EXP_K_SMALL
        );

        run_case(
            "R1_e_high",
            TEST_D,
            TEST_E_HIGH,
            N_R1,
            EXP_K_HIGH_R1
        );

        run_case(
            "K1_e_high",
            TEST_D,
            TEST_E_HIGH,
            N_K1,
            EXP_K_HIGH_K1
        );

        $display("TB finished.");
        $finish;
    end

endmodule
