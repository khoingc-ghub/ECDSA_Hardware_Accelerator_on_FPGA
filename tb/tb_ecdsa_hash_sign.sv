`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/02/2026 04:49:44 PM
// Design Name: 
// Module Name: tb_ecdsa_hash_sign
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

module tb_ecdsa_hash_sign;

    logic clk;
    logic rst_n;

    logic start;
    logic curve_sel;
    logic use_external_k;
    logic use_hash;

    logic [511:0] msg_block;
    logic [255:0] k_in;
    logic [255:0] d_in;
    logic [255:0] e_in;

    logic busy;
    logic done;

    logic [255:0] e_hash;
    logic [255:0] r_out;
    logic [255:0] s_out;

    integer cycle_cnt;

    localparam logic [511:0] MSG_ABC_BLOCK =
        512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;

    localparam logic [255:0] SHA_ABC_DIGEST =
        256'hE3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855;

    localparam logic [255:0] D_ONE =
        256'h0000000000000000000000000000000000000000000000000000000000000001;

    // Tạm thời để placeholder.
    // Mình sẽ tính expected bằng Python ở bước sau nếu bạn chưa có.
    localparam logic [255:0] R1_ABC_K =
        256'hbacb7c191eacd08f7d3526a540371c6399744a97d2328c521c685c1dbdd37b88;

    localparam logic [255:0] R1_ABC_R =
        256'h0e69cb117664cedd6734e80151eabd388de266533e163fbe8ea463065c0fd71a;

    localparam logic [255:0] R1_ABC_S =
        256'hc284e67e0baf2cf8e07896a5c5f222cad11e35c997c18c59d79bdbad6881783c;

    localparam logic [255:0] K1_ABC_K =
        256'hbacb7c191eacd08f7d3526a540371c6399744a97d2328c521c685c1dbdd37b88;

    localparam logic [255:0] K1_ABC_R =
        256'h77c8d336572f6f466055b5f70f433851f8f535f6c4fc71133a6cfd71079d03b7;

    localparam logic [255:0] K1_ABC_S =
        256'h0ed9f5eb8aa5b266abac35d416c3207e7a538bf5f37649727d7a9823b1069577;

    //=====//
    // dut //
    //=====//
    ecdsa_hash_sign_top dut (
        .clk_i             (clk),
        .rst_ni            (rst_n),

        .start_i           (start),
        .curve_sel_i       (curve_sel),

        .use_external_k_i  (use_external_k),
        .use_hash_i        (use_hash),

        .msg_block_i       (msg_block),

        .k_i               (k_in),
        .d_i               (d_in),
        .e_i               (e_in),

        .busy_o            (busy),
        .done_o            (done),

        .e_hash_o          (e_hash),
        .r_o               (r_out),
        .s_o               (s_out)
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

    //==============//
    // check helper //
    //==============//
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
                $display("[PASS] %s", name);
                $display("  val = %064h", got);
            end
        end
    endtask

    //==========//
    // run case //
    //==========//
    task automatic run_hash_case (
        input string        name,
        input logic         curve,
        input logic [255:0] exp_k,
        input logic [255:0] exp_r,
        input logic [255:0] exp_s
    );
        integer timeout;
        integer start_cyc;
        integer done_cyc;

        begin
            @(negedge clk);

            curve_sel      <= curve;
            use_external_k <= 1'b0;
            use_hash       <= 1'b1;

            msg_block      <= MSG_ABC_BLOCK;
            k_in           <= '0;
            d_in           <= D_ONE;
            e_in           <= '0;

            start          <= 1'b1;
            start_cyc      = cycle_cnt;

            @(negedge clk);
            start <= 1'b0;

            timeout = 0;

            while (done !== 1'b1) begin
                @(posedge clk);
                timeout++;

                if (timeout > 6_000_000) begin
                    $display("[TIMEOUT] %s", name);
                    $display("  cycle = %0d", cycle_cnt);
                    $display("  top_state  = %0d", dut.state_q);
                    $display("  sign_state = %0d", dut.U_ECDSA_SIGN.state_q);
                    $finish;
                end
            end

            done_cyc = cycle_cnt;

            @(negedge clk);

            $display("============================================================");
            $display("CASE      : %s", name);
            $display("CURVE     : %s", curve ? "secp256k1" : "secp256r1");
            $display("e_hash    : %064h", e_hash);
            $display("k_final   : %064h", dut.U_ECDSA_SIGN.k_r);
            $display("r_out     : %064h", r_out);
            $display("s_out     : %064h", s_out);
            $display("cycles    : %0d", done_cyc - start_cyc);

            check_equal_256({name, " e_hash"}, e_hash, SHA_ABC_DIGEST);
            check_equal_256({name, " k"}, dut.U_ECDSA_SIGN.k_r, exp_k);
            check_equal_256({name, " r"}, r_out, exp_r);
            check_equal_256({name, " s"}, s_out, exp_s);

            $display("============================================================");

            repeat (5) @(negedge clk);
        end
    endtask

    //======//
    // main //
    //======//
    initial begin
        rst_n          = 1'b0;
        start          = 1'b0;
        curve_sel      = 1'b0;
        use_external_k = 1'b0;
        use_hash       = 1'b0;

        msg_block      = '0;
        k_in           = '0;
        d_in           = '0;
        e_in           = '0;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (10) @(negedge clk);

        run_hash_case(
            "r1_sha_abc_rfc6979_d1",
            1'b0,
            R1_ABC_K,
            R1_ABC_R,
            R1_ABC_S
        );

        run_hash_case(
            "k1_sha_abc_rfc6979_d1",
            1'b1,
            K1_ABC_K,
            K1_ABC_R,
            K1_ABC_S
        );

        $display("TB finished.");
        $finish;
    end

    //==============//
    // useful debug //
    //==============//
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (dut.sha_start) begin
                $display("[SHA START] cyc=%0d", cycle_cnt);
            end

            if (dut.sha_done) begin
                $display("[SHA DONE ] cyc=%0d digest=%064h",
                    cycle_cnt, dut.sha_digest);
            end

            if (dut.sign_start) begin
                $display("[SIGN START] cyc=%0d e_to_sign=%064h",
                    cycle_cnt, dut.e_to_sign);
            end

            if (dut.U_ECDSA_SIGN.nonce_done) begin
                $display("[NONCE DONE] cyc=%0d k=%064h",
                    cycle_cnt, dut.U_ECDSA_SIGN.nonce_k);
            end

            if (dut.U_ECDSA_SIGN.kg_start) begin
                $display("[KG START ] cyc=%0d k_r=%064h",
                    cycle_cnt, dut.U_ECDSA_SIGN.k_r);
            end

            if (dut.U_ECDSA_SIGN.scalar_done) begin
                $display("[SCALAR DONE] cyc=%0d s=%064h",
                    cycle_cnt, dut.U_ECDSA_SIGN.s_calc);
            end
        end
    end

endmodule
