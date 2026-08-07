`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2026 06:25:34 PM
// Design Name: 
// Module Name: tb_inv
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

module tb_inv;

    logic clk;
    logic rst_n;
    logic start;

    logic [255:0] a;
    logic [255:0] p;
    logic [255:0] M;

    logic [255:0] r;
    logic done;
    logic busy;

    integer cycle_cnt;

    //====================//
    // secp256r1 mod p    //
    //====================//
    localparam logic [255:0] P_R1 =
        256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;

    localparam logic [255:0] ONE_P_R1 =
        256'h0000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000010;

    localparam logic [255:0] R2_P_R1 =
        256'h000004FFFFFFFDFFFFFFFFFFFFFFFEFFFFFFFBFFFFFFFF000000000000000300;

    //====================//
    // secp256k1 mod p    //
    //====================//
    localparam logic [255:0] P_K1 =
        256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    localparam logic [255:0] ONE_P_K1 =
        256'h0000000000000000000000000000000000000000000000000000001000003D10;

    localparam logic [255:0] R2_P_K1 =
        256'h0000000000000000000000000000000000000000000001000007A2000E90A100;

    //=====//
    // DUT //
    //=====//
    inv #(
        .N(256)
    ) dut (
        .clk    (clk),
        .reset  (rst_n),
        .start  (start),
        .a      (a),
        .p      (p),
        .M      (M),
        .r      (r),
        .done   (done),
        .busy   (busy)
    );

    //=======//
    // clock //
    //=======//
    initial clk = 1'b0;
    always #5 clk = ~clk;

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

    //=======//
    // check //
    //=======//
    task automatic check_equal_256 (
        input string        name,
        input logic [255:0] got,
        input logic [255:0] exp
    );
        begin
            if (got !== exp) begin
                $display("[FAIL] %s", name);
                $display("  got = %064h", got);
                $display("  exp = %064h", exp);
            end
            else begin
                $display("[PASS] %s = %064h", name, got);
            end
        end
    endtask

    //==========//
    // run case //
    //==========//
    task automatic run_case (
        input string        name,
        input logic [255:0] a_val,
        input logic [255:0] p_val,
        input logic [255:0] M_val,
        input logic [255:0] exp_val
    );
        integer timeout;
        integer start_cyc;
        integer done_cyc;
        begin
            @(negedge clk);
            a     <= a_val;
            p     <= p_val;
            M     <= M_val;
            start <= 1'b1;
            start_cyc = cycle_cnt;

            @(negedge clk);
            start <= 1'b0;

            timeout = 0;
            while (done !== 1'b1) begin
                @(posedge clk);
                timeout = timeout + 1;

                if (timeout > 2000) begin
                    $display("[TIMEOUT] %s", name);
                    $display("a    = %064h", a_val);
                    $display("p    = %064h", p_val);
                    $display("M    = %064h", M_val);
                    $display("busy = %0b done = %0b", busy, done);
                    $finish;
                end
            end

            done_cyc = cycle_cnt;

            @(negedge clk);
            $display("============================================================");
            $display("CASE   : %s", name);
            $display("cycles : %0d", done_cyc - start_cyc);
            $display("r      : %064h", r);
            check_equal_256(name, r, exp_val);
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
        a = '0;
        p = '0;
        M = '0;

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        // a = 1 => r = M
        run_case(
            "R1 inv(1) * R2 = R2",
            256'd1,
            P_R1,
            R2_P_R1,
            R2_P_R1
        );

        // a = R => r = R
        run_case(
            "R1 inv(ONE_MONT) * R2 = ONE_MONT",
            ONE_P_R1,
            P_R1,
            R2_P_R1,
            ONE_P_R1
        );

        // a = 1 => r = M
        run_case(
            "K1 inv(1) * R2 = R2",
            256'd1,
            P_K1,
            R2_P_K1,
            R2_P_K1
        );

        // a = R => r = R
        run_case(
            "K1 inv(ONE_MONT) * R2 = ONE_MONT",
            ONE_P_K1,
            P_K1,
            R2_P_K1,
            ONE_P_K1
        );

        $display("TB_INV finished.");
        $finish;
    end

endmodule