`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/24/2026 09:19:48 PM
// Design Name: 
// Module Name: tb_ecc
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




module tb_ecc;

    // ============================================================
    // TB config
    // ============================================================
    localparam int CLK_PERIOD_NS       = 10;   // 100 MHz
    localparam int CLKS_PER_BIT        = 16;   // mô phỏng nhanh
    localparam int BIT_TIME_NS         = CLK_PERIOD_NS * CLKS_PER_BIT;
    localparam int UART_BYTES_PER_RESP = 204;  // X/Y/Z response 1 lần
    localparam int NUM_TESTS           = 2;
    localparam int TOTAL_RX_BYTES      = UART_BYTES_PER_RESP * NUM_TESTS;

    // ============================================================
    // DUT signals
    // ============================================================
    logic clk;
    logic clk_p;
    logic clk_n;

    logic [7:0] PL_USER_PB;
    logic [7:0] PL_USER_LED;

    tri [7:0] JA_tri_io;

    logic tb_uart_tx_to_fpga;
    wire  fpga_uart_tx_to_tb;

    logic [31:0] rx_count_global;
    logic [31:0] packet_count_done;

    assign clk_p = clk;
    assign clk_n = ~clk;

    // ECC_top:
    // JA_tri_io[0] = FPGA RX
    // JA_tri_io[2] = FPGA TX
    assign JA_tri_io[0] = tb_uart_tx_to_fpga;
    assign fpga_uart_tx_to_tb = JA_tri_io[2];

    assign JA_tri_io[1] = 1'bz;
    assign JA_tri_io[3] = 1'bz;
    assign JA_tri_io[4] = 1'bz;
    assign JA_tri_io[5] = 1'bz;
    assign JA_tri_io[6] = 1'bz;
    assign JA_tri_io[7] = 1'bz;

    // ============================================================
    // DUT
    // ============================================================
    ECC_top #(
        .DEPTH(4),
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk              (clk),
        .CLK_IN1_D_0_clk_p(clk_p),
        .CLK_IN1_D_0_clk_n(clk_n),
        .PL_USER_PB       (PL_USER_PB),
        .PL_USER_LED      (PL_USER_LED),
        .JA_tri_io        (JA_tri_io)
    );

    // ============================================================
    // Clock 100 MHz
    // ============================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // ============================================================
    // UART send byte vào FPGA RX
    // 8N1, LSB first
    // ============================================================
    task automatic uart_send_byte(input logic [7:0] data);
        int i;
        begin
            tb_uart_tx_to_fpga = 1'b1;
            #(BIT_TIME_NS);

            // start bit
            tb_uart_tx_to_fpga = 1'b0;
            #(BIT_TIME_NS);

            // data bit LSB first
            for (i = 0; i < 8; i++) begin
                tb_uart_tx_to_fpga = data[i];
                #(BIT_TIME_NS);
            end

            // stop bit
            tb_uart_tx_to_fpga = 1'b1;
            #(BIT_TIME_NS);

            // idle gap giữa 2 byte
            #(BIT_TIME_NS);
        end
    endtask

    task automatic uart_send_hex64(input string s);
        int i;
        begin
            if (s.len() != 64) begin
                $display("[%0t] ERROR: scalar length = %0d, cần đúng 64 hex chars",
                         $time, s.len());
                $finish;
            end

            $display("[%0t] TB send k = %s", $time, s);

            for (i = 0; i < 64; i++) begin
                uart_send_byte(s[i]);
            end
        end
    endtask

    // ============================================================
    // UART receive byte từ FPGA TX
    // ============================================================
    task automatic uart_recv_byte(output logic [7:0] data);
        int i;
        begin
            data = 8'h00;

            // chờ start bit
            wait (fpga_uart_tx_to_tb === 1'b0);

            // tới giữa data bit 0
            #(BIT_TIME_NS + BIT_TIME_NS/2);

            for (i = 0; i < 8; i++) begin
                data[i] = fpga_uart_tx_to_tb;
                #(BIT_TIME_NS);
            end

            // bỏ qua nửa stop bit còn lại
            #(BIT_TIME_NS/2);
        end
    endtask

    // ============================================================
    // Monitor FPGA TX
    // ============================================================
    initial begin : RX_MONITOR
        logic [7:0] b;

        rx_count_global  = 0;
        packet_count_done = 0;

        wait (PL_USER_PB[0] == 1'b0);
        repeat (20) @(posedge clk);

        $display("[%0t] RX monitor started", $time);

        forever begin
            uart_recv_byte(b);
            rx_count_global++;

            if ((rx_count_global % UART_BYTES_PER_RESP) == 1) begin
                $display("\n\n[%0t] ===== RX PACKET %0d BEGIN =====",
                         $time, (rx_count_global / UART_BYTES_PER_RESP) + 1);
            end

            if (b == 8'h0D) begin
                $write("\\r");
            end else if (b == 8'h0A) begin
                $write("\\n\n");
            end else begin
                $write("%s", b);
            end

            if ((rx_count_global % UART_BYTES_PER_RESP) == 0) begin
                packet_count_done++;
                $display("\n[%0t] ===== RX PACKET %0d DONE, bytes=%0d =====",
                         $time, packet_count_done, UART_BYTES_PER_RESP);
            end

            if (rx_count_global >= TOTAL_RX_BYTES) begin
                $display("\n[%0t] DONE: received total %0d UART bytes, packets=%0d",
                         $time, rx_count_global, packet_count_done);
                #(20 * BIT_TIME_NS);
                $finish;
            end
        end
    end

    // ============================================================
    // Main stimulus
    // ============================================================
    initial begin
        tb_uart_tx_to_fpga = 1'b1;
        PL_USER_PB         = 8'd0;

        // Reset active high BTN0
        PL_USER_PB[0] = 1'b1;
        repeat (20) @(posedge clk);
        PL_USER_PB[0] = 1'b0;

        repeat (50) @(posedge clk);

        // ========================================================
        // Gửi k = 4 lần 1
        // ========================================================
        $display("\n[%0t] ===== SEND TEST 1 =====", $time);
        uart_send_hex64(
            "0000000000000000000000000000000000000000000000000000000000000004"
        );

        // Chờ nhận xong packet 1 rồi mới gửi packet 2
        wait (packet_count_done == 1);
        repeat (200) @(posedge clk);

        // ========================================================
        // Gửi k = 4 lần 2
        // ========================================================
        $display("\n[%0t] ===== SEND TEST 2 =====", $time);
        uart_send_hex64(
            "0000000000000000000000000000000000000000000000000000000000000004"
        );

        // Timeout tổng, nếu core ECC thật chạy lâu thì tăng số này
        #(80_000_000);

        $display("\n[%0t] TIMEOUT: chưa nhận đủ 2 UART output", $time);
        $display("[%0t] rx_count_global=%0d, packet_count_done=%0d",
                 $time, rx_count_global, packet_count_done);
        $finish;
    end

endmodule