`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 10:58:29 PM
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


`timescale 1ns / 1ps

module tb;

    localparam int SCALAR_W = 256;
    localparam int DEPTH    = 4;

    // =====================================================
    // secp256r1 order
    // =====================================================
    localparam logic [255:0] ORDER_R1 =
        256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

    // =====================================================
    // secp256k1 order
    // =====================================================
    localparam logic [255:0] ORDER_K1 =
        256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    logic clk;
    logic rst_n;
    logic start;

    logic curve_sel;   // 0: secp256r1, 1: secp256k1
    logic [SCALAR_W-1:0] k_in;

    logic busy;
    logic done;
    logic [255:0] X_out;
    logic [255:0] Y_out;
    logic [255:0] Z_out;

    // =====================================================
    // DUT
    // =====================================================
    double_and_add #(
        .SCALAR_W (SCALAR_W),
        .DEPTH    (DEPTH)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .curve_sel (curve_sel),
        .k_in      (k_in),

        .busy      (busy),
        .done      (done),

        .X_out     (X_out),
        .Y_out     (Y_out),
        .Z_out     (Z_out)
    );

    // =====================================================
    // Clock 100 MHz
    // =====================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =====================================================
    // Task chạy 1 test case
    // curve = 0: secp256r1
    // curve = 1: secp256k1
    // =====================================================
    // =====================================================
// Cycle counter + ECPA/ECPD latency monitor
// =====================================================
integer cycle_cnt;

integer case_start_cyc;
integer case_done_cyc;

integer ecpa_start_cyc;
integer ecpd_start_cyc;

integer ecpa_lat;
integer ecpd_lat;

integer ecpa_count;
integer ecpd_count;

integer ecpa_total_cyc;
integer ecpd_total_cyc;

// Set 1 để in từng lần ECPA/ECPD, set 0 để chỉ in summary mỗi case
localparam bit DEBUG_EC_OPS = 1'b1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycle_cnt <= 0;
    end
    else begin
        cycle_cnt <= cycle_cnt + 1;
    end
end

always @(posedge clk) begin
    if (rst_n) begin
        // -------------------------------
        // ECPA monitor
        // -------------------------------
        if (dut.ecpa_start) begin
            ecpa_start_cyc = cycle_cnt;

            if (DEBUG_EC_OPS) begin
                $display("[ECPA START] cyc=%0d", cycle_cnt);
                $display("  P1 = (%064h, %064h, %064h)",
                         dut.add_X1_r, dut.add_Y1_r, dut.add_Z1_r);
                $display("  P2 = (%064h, %064h, %064h)",
                         dut.add_X2_r, dut.add_Y2_r, dut.add_Z2_r);
            end
        end

        if (dut.ecpa_done) begin
            ecpa_lat = cycle_cnt - ecpa_start_cyc;
            ecpa_count = ecpa_count + 1;
            ecpa_total_cyc = ecpa_total_cyc + ecpa_lat;

            if (DEBUG_EC_OPS) begin
                $display("[ECPA DONE ] cyc=%0d, latency=%0d cycles",
                         cycle_cnt, ecpa_lat);
                $display("  P3 = (%064h, %064h, %064h)",
                         dut.ecpa_X3_out, dut.ecpa_Y3_out, dut.ecpa_Z3_out);
            end
        end

        // -------------------------------
        // ECPD monitor
        // -------------------------------
        if (dut.ecpd_start) begin
            ecpd_start_cyc = cycle_cnt;

            if (DEBUG_EC_OPS) begin
                $display("[ECPD START] cyc=%0d", cycle_cnt);
                $display("  P1 = (%064h, %064h, %064h)",
                         dut.dbl_X1_r, dut.dbl_Y1_r, dut.dbl_Z1_r);
            end
        end

        if (dut.ecpd_done) begin
            ecpd_lat = cycle_cnt - ecpd_start_cyc;
            ecpd_count = ecpd_count + 1;
            ecpd_total_cyc = ecpd_total_cyc + ecpd_lat;

            if (DEBUG_EC_OPS) begin
                $display("[ECPD DONE ] cyc=%0d, latency=%0d cycles",
                         cycle_cnt, ecpd_lat);
                $display("  P3 = (%064h, %064h, %064h)",
                         dut.ecpd_X3_out, dut.ecpd_Y3_out, dut.ecpd_Z3_out);
            end
        end
    end
end

    task automatic run_case(
    input string        name,
    input logic         curve,     // 0: secp256r1, 1: secp256k1
    input logic [255:0] k_val
);
    integer timeout;
    begin
        // reset counter thống kê cho case này
        ecpa_count     = 0;
        ecpd_count     = 0;
        ecpa_total_cyc = 0;
        ecpd_total_cyc = 0;

        @(negedge clk);
        curve_sel      <= curve;
        k_in           <= k_val;
        start          <= 1'b1;
        case_start_cyc = cycle_cnt;

        @(negedge clk);
        start <= 1'b0;

        timeout = 0;
        while (done !== 1'b1) begin
            @(posedge clk);
            timeout = timeout + 1;

            if (timeout > 3000000) begin
                $display("TIMEOUT at case %s", name);
                $display("curve_sel = %0d", curve);
                $display("k         = %064h", k_val);
                $finish;
            end
        end

        case_done_cyc = cycle_cnt;

        @(negedge clk);
        $display("============================================================");
        $display("CASE      : %s", name);
        $display("CURVE     : %s", curve ? "secp256k1" : "secp256r1");
        $display("curve_sel : %0d", curve);
        $display("k         : %064h", k_val);
        $display("Xout      : %064h", X_out);
        $display("Yout      : %064h", Y_out);
        $display("Zout      : %064h", Z_out);

        $display("---------------- Cycle summary ----------------");
        $display("TOTAL cycles : %0d", case_done_cyc - case_start_cyc);
        $display("ECPA count   : %0d", ecpa_count);
        $display("ECPD count   : %0d", ecpd_count);

        if (ecpa_count != 0) begin
            $display("ECPA total   : %0d cycles", ecpa_total_cyc);
            $display("ECPA avg     : %0d cycles", ecpa_total_cyc / ecpa_count);
        end

        if (ecpd_count != 0) begin
            $display("ECPD total   : %0d cycles", ecpd_total_cyc);
            $display("ECPD avg     : %0d cycles", ecpd_total_cyc / ecpd_count);
        end

        $display("============================================================");

        repeat (3) @(negedge clk);
    end
endtask

    // =====================================================
    // Main test
    // =====================================================
    initial begin
        rst_n     = 1'b0;
        start     = 1'b0;
        curve_sel = 1'b0;
        k_in      = '0;

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        // =================================================
        // Test secp256r1
        // =================================================
        run_case("r1_k0"   , 1'b0, 256'h62C4CE3F362E1E7B1DD9DC4B48D15A5FF6829190A5F2A07932150E0E9B378778);
        run_case("r1_k1"   , 1'b0, 256'd1);
        run_case("r1_k2"   , 1'b0, 256'd2);
        run_case("r1_k3"   , 1'b0, 256'd3);
        run_case("r1_k4"   , 1'b0, 256'd4);
        run_case("r1_k5"   , 1'b0, 256'd5);
        run_case("r1_k10"  , 1'b0, 256'd10);
        //run_case("r1_n_1"  , 1'b0, ORDER_R1 - 1'b1);
        //run_case("r1_n"    , 1'b0, ORDER_R1);

        // =================================================
        // Test secp256k1
        // Bật nếu bạn đã chắc constants K1 trong double_and_add đúng.
        // =================================================
        run_case("k1_k0"   , 1'b1, 256'd0);
        run_case("k1_k1"   , 1'b1, 256'd1);
        run_case("k1_k2"   , 1'b1, 256'd2);
        run_case("k1_k3"   , 1'b1, 256'd3);
        run_case("k1_k4"   , 1'b1, 256'd4);
        run_case("k1_k5"   , 1'b1, 256'd5);
        run_case("k1_k10"  , 1'b1, 256'd10);
        //run_case("k1_n_1"  , 1'b1, ORDER_K1 - 1'b1);
        //run_case("k1_n"    , 1'b1, ORDER_K1);

        $display("TB finished.");
        $finish;
    end

endmodule

/*module tb;

    localparam int SCALAR_W = 256;
    localparam int DEPTH    = 4;
    localparam int CLK_HALF = 5;   // 100 MHz

    // Constants theo double_and_add.sv
    localparam logic [255:0] ONE_MONT =
        256'h0000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000010;

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

    // Giống ECC_top
    logic         start_core;
    logic         busy_core;
    logic         done_core;
    logic [255:0] k_reg;
    logic [255:0] X_out, Y_out, Z_out;
    logic [255:0] X_lat, Y_lat, Z_lat;

    logic start_latched;
    logic done_latched;

    int cycle_cnt;
    int pass_cnt;
    int fail_cnt;

    double_and_add #(
        .SCALAR_W(SCALAR_W),
        .DEPTH   (DEPTH)
    ) U_ECC (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start_core),
        .k_in  (k_reg),
        .busy  (busy_core),
        .done  (done_core),
        .X_out (X_out),
        .Y_out (Y_out),
        .Z_out (Z_out)
    );

    initial begin
        clk = 1'b0;
        forever #CLK_HALF clk = ~clk;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_cnt <= 0;
        else
            cycle_cnt <= cycle_cnt + 1;
    end

    typedef enum logic [2:0] {
        TB_IDLE,
        TB_LOAD_K,
        TB_START,
        TB_WAIT_DONE,
        TB_LATCHED
    } tb_state_t;

    tb_state_t tb_state;

    logic        tb_req;
    logic [255:0] tb_req_k;
    logic        tb_case_done;

    // ============================================================
    // FSM giả lập đúng kiểu ECC_top:
    // - sau khi "nhận đủ k", vào ST_START
    // - nếu !busy_core thì start_core = 1 đúng 1 clk
    // - sang WAIT_DONE
    // - thấy done_core thì latch X_out/Y_out/Z_out vào X_lat/Y_lat/Z_lat
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tb_state      <= TB_IDLE;
            start_core    <= 1'b0;
            k_reg         <= '0;
            X_lat         <= '0;
            Y_lat         <= '0;
            Z_lat         <= '0;
            start_latched <= 1'b0;
            done_latched  <= 1'b0;
            tb_case_done  <= 1'b0;
        end else begin
            start_core   <= 1'b0;
            tb_case_done <= 1'b0;

            case (tb_state)
                TB_IDLE: begin
                    start_latched <= 1'b0;
                    done_latched  <= 1'b0;

                    if (tb_req) begin
                        k_reg    <= tb_req_k;
                        tb_state <= TB_START;
                    end
                end

                TB_START: begin
                    // Giống ST_START trong ECC_top
                    if (!busy_core) begin
                        start_core    <= 1'b1;
                        start_latched <= 1'b1;
                        tb_state      <= TB_WAIT_DONE;
                    end
                end

                TB_WAIT_DONE: begin
                    // Giống ST_WAIT_DONE trong ECC_top
                    if (done_core) begin
                        X_lat         <= X_out;
                        Y_lat         <= Y_out;
                        Z_lat         <= Z_out;
                        done_latched  <= 1'b1;
                        start_latched <= 1'b0;
                        tb_state      <= TB_LATCHED;
                    end
                end

                TB_LATCHED: begin
                    tb_case_done <= 1'b1;
                    tb_state     <= TB_IDLE;
                end

                default: begin
                    tb_state <= TB_IDLE;
                end
            endcase
        end
    end

    task automatic reset_dut;
        begin
            rst_n  = 1'b0;
            tb_req = 1'b0;
            tb_req_k = '0;

            repeat (20) @(posedge clk);
            rst_n = 1'b1;
            repeat (20) @(posedge clk);
        end
    endtask

    task automatic check_equal_256(
        input string name,
        input logic [255:0] got,
        input logic [255:0] exp
    );
        begin
            if (got !== exp) begin
                $display("[FAIL] %s", name);
                $display("       got = %064h", got);
                $display("       exp = %064h", exp);
                fail_cnt++;
            end else begin
                $display("[PASS] %s = %064h", name, got);
                pass_cnt++;
            end
        end
    endtask

    task automatic run_case_ecc_top_style(
        input  string        case_name,
        input  logic [255:0] k_val,
        output logic [255:0] X_res,
        output logic [255:0] Y_res,
        output logic [255:0] Z_res
    );
        int timeout;
        int start_cycle;
        int done_cycle;
        begin
            wait (tb_state == TB_IDLE);
            wait (busy_core == 1'b0);
            repeat (5) @(posedge clk);

            $display("");
            $display("============================================================");
            $display("START CASE : %s", case_name);
            $display("k          : %064h", k_val);

            @(negedge clk);
            tb_req_k <= k_val;
            tb_req   <= 1'b1;

            @(negedge clk);
            tb_req   <= 1'b0;

            start_cycle = cycle_cnt;
            timeout = 0;

            while (tb_case_done !== 1'b1) begin
                @(posedge clk);
                timeout++;

                if (start_core) begin
                    $display("[INFO] start_core pulse at cycle %0d, busy=%b done=%b",
                             cycle_cnt, busy_core, done_core);
                end

                if (done_core) begin
                    $display("[INFO] done_core seen  at cycle %0d", cycle_cnt);
                    $display("[INFO] X_out at done_core = %064h", X_out);
                    $display("[INFO] Y_out at done_core = %064h", Y_out);
                    $display("[INFO] Z_out at done_core = %064h", Z_out);
                end

                if (timeout > 5_000_000) begin
                    $display("[TIMEOUT] %s", case_name);
                    $display("cycle=%0d tb_state=%0d busy=%b done=%b start=%b",
                             cycle_cnt, tb_state, busy_core, done_core, start_core);

                    $display("DUT state = %0d", U_ECC.state);
                    $finish;
                end
            end

            done_cycle = cycle_cnt;

            // Chờ 1 cạnh để chắc X_lat/Y_lat/Z_lat đã update xong sau nonblocking
            @(posedge clk);

            X_res = X_lat;
            Y_res = Y_lat;
            Z_res = Z_lat;

            $display("[INFO] latched at cycle = %0d", done_cycle);
            $display("X_lat      : %064h", X_res);
            $display("Y_lat      : %064h", Y_res);
            $display("Z_lat      : %064h", Z_res);
            $display("latency    : %0d cycles", done_cycle - start_cycle);
            $display("============================================================");

            repeat (10) @(posedge clk);
        end
    endtask

    task automatic run_case_expect(
        input string        case_name,
        input logic [255:0] k_val,
        input logic [255:0] X_exp,
        input logic [255:0] Y_exp,
        input logic [255:0] Z_exp
    );
        logic [255:0] X_res;
        logic [255:0] Y_res;
        logic [255:0] Z_res;
        begin
            run_case_ecc_top_style(case_name, k_val, X_res, Y_res, Z_res);

            check_equal_256({case_name, ".X_lat"}, X_res, X_exp);
            check_equal_256({case_name, ".Y_lat"}, Y_res, Y_exp);
            check_equal_256({case_name, ".Z_lat"}, Z_res, Z_exp);
        end
    endtask

    logic [255:0] X4_a, Y4_a, Z4_a;
    logic [255:0] X4_b, Y4_b, Z4_b;
    logic [255:0] X3, Y3, Z3;
    logic [255:0] X5, Y5, Z5;

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        reset_dut();

        // k = 0, 1, 2 có expected rõ trong double_and_add
        run_case_expect(
            "k = 0",
            256'd0,
            256'd0,
            256'd0,
            256'd0
        );

        run_case_expect(
            "k = 1",
            256'd1,
            GX_MONT,
            GY_MONT,
            ONE_MONT
        );

        run_case_expect(
            "k = 2",
            256'd2,
            X2G_MONT,
            Y2G_MONT,
            ONE_MONT
        );

        // Quan trọng nhất: cùng k = 4 chạy 2 lần phải ra y hệt
        run_case_ecc_top_style("k = 4, run 1", 256'd4, X4_a, Y4_a, Z4_a);
        run_case_ecc_top_style("k = 4, run 2", 256'd4, X4_b, Y4_b, Z4_b);

        check_equal_256("repeat k4 X_lat", X4_b, X4_a);
        check_equal_256("repeat k4 Y_lat", Y4_b, Y4_a);
        check_equal_256("repeat k4 Z_lat", Z4_b, Z4_a);

        // In thêm vài case để lấy giá trị so với board
        run_case_ecc_top_style("k = 3", 256'd3, X3, Y3, Z3);
        run_case_ecc_top_style("k = 5", 256'd5, X5, Y5, Z5);

        $display("");
        $display("============================================================");
        $display("TB DONE");
        $display("PASS = %0d", pass_cnt);
        $display("FAIL = %0d", fail_cnt);
        $display("============================================================");

        if (fail_cnt == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $finish;
    end

endmodule*/