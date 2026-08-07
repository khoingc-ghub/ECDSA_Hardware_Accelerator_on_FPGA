`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 08:34:34 PM
// Design Name: 
// Module Name: tb_hmac_drbg_msg
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

module tb_hmac_drbg_msg;

    logic clk;
    logic rst_n;

    logic start;
    logic [1:0] mode;

    logic [255:0] key;
    logic [255:0] V;
    logic [7:0]   prefix;
    logic [255:0] d;
    logic [255:0] e_mod;

    logic busy;
    logic done;
    logic [255:0] tag;

    integer cycle_cnt;

    localparam logic [255:0] TEST_KEY =
        256'h0000000000000000000000000000000000000000000000000000000000000000;

    localparam logic [255:0] TEST_V =
        256'h0101010101010101010101010101010101010101010101010101010101010101;

    localparam logic [255:0] TEST_D =
        256'h0202020202020202020202020202020202020202020202020202020202020202;

    localparam logic [255:0] TEST_E =
        256'h0303030303030303030303030303030303030303030303030303030303030303;

    localparam logic [255:0] EXP_MODE0 =
        256'h80A09DE3BFE30DA90116E588ADE2F812D49B55625BE8B4ABBFF775FA5A5A74E9;

    localparam logic [255:0] EXP_MODE1_PREFIX0 =
        256'hC3FD99A25DDD68D2DBE2E1383E00E33700BAFFC12A3DFF2C4F821D45EE8D90DA;
    
    localparam logic [255:0] EXP_MODE1_PREFIX1 =
        256'hF854070CD9745F9C7581AC06DE4526E327BA716819DD057B132380D772BB551A;
    
    localparam logic [255:0] EXP_MODE2 =
        256'hA3E7776DD1FC680D83B09551D2B1177A5C810BDBDB61B023909C6F0A42C2D204;

    //=====//
    // dut //
    //=====//
    hmac_drbg_msg dut (
        .clk_i     (clk),
        .rst_ni    (rst_n),

        .start_i   (start),
        .mode_i    (mode),

        .key_i     (key),
        .V_i       (V),
        .prefix_i  (prefix),
        .d_i       (d),
        .e_mod_i   (e_mod),

        .busy_o    (busy),
        .done_o    (done),
        .tag_o     (tag)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
        end
        else begin
            cycle_cnt <= cycle_cnt + 1;
        end
    end

    task automatic run_case (
        input string        name,
        input logic [1:0]   mode_val,
        input logic [7:0]   prefix_val,
        input logic [255:0] exp_tag
    );
        integer start_cyc;
        integer done_cyc;
        integer timeout;

        begin
            @(negedge clk);

            key     <= TEST_KEY;
            V       <= TEST_V;
            d       <= TEST_D;
            e_mod   <= TEST_E;
            mode    <= mode_val;
            prefix  <= prefix_val;

            start   <= 1'b1;
            start_cyc = cycle_cnt;

            @(negedge clk);
            start <= 1'b0;

            timeout = 0;

            while (done !== 1'b1) begin
                @(posedge clk);
                timeout++;

                if (timeout > 10000) begin
                    $display("[TIMEOUT] %s", name);
                    $finish;
                end
            end

            done_cyc = cycle_cnt;

            @(negedge clk);

            $display("============================================================");
            $display("CASE   : %s", name);
            $display("mode   : %0d", mode_val);
            $display("prefix : %02h", prefix_val);
            $display("tag    : %064h", tag);
            $display("expect : %064h", exp_tag);
            $display("cycles : %0d", done_cyc - start_cyc);

            if (tag === exp_tag) begin
                $display("[PASS] %s", name);
            end
            else begin
                $display("[FAIL] %s", name);
            end

            $display("============================================================");

            repeat (5) @(negedge clk);
        end
    endtask

    initial begin
        rst_n  = 1'b0;
        start  = 1'b0;
        mode   = 2'd0;
        prefix = 8'h00;

        key    = '0;
        V      = '0;
        d      = '0;
        e_mod  = '0;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (10) @(negedge clk);

        run_case(
            "mode0_hmac_K_V",
            2'd0,
            8'h00,
            EXP_MODE0
        );

        run_case(
            "mode1_hmac_K_V_00_d_e",
            2'd1,
            8'h00,
            EXP_MODE1_PREFIX0
        );

        run_case(
            "mode1_hmac_K_V_01_d_e",
            2'd1,
            8'h01,
            EXP_MODE1_PREFIX1
        );

        run_case(
            "mode2_hmac_K_V_00",
            2'd2,
            8'h00,
            EXP_MODE2
        );

        $display("TB finished.");
        $finish;
    end

endmodule
