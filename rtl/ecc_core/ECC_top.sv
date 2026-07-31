`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/19/2026 11:19:11 PM
// Design Name: 
// Module Name: ECC_top
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



module ECC_top #(
    parameter int DEPTH        = 4,
    parameter int CLKS_PER_BIT = 868   // 100MHz / 115200
)(
    //input  logic       clk, 
    input  logic       CLK_IN1_D_0_clk_p,
    input  logic       CLK_IN1_D_0_clk_n,
    input  logic [7:0] PL_USER_PB,   // active-high pushbuttons; PB[0] dùng làm reset
    input  logic [1:0] PL_USER_SW,
    output logic [7:0] PL_USER_LED,

    inout  wire  [7:0] JA_tri_io
);

    logic clk;
    logic locked_0;

    // Reset: nhấn PL_USER_PB[0] hoặc clock wizard chưa locked => reset.
    // rst_n được nhả đồng bộ theo clk để các FSM/UART/core khởi động sạch trên FPGA.
    logic       reset_req;
    logic [3:0] rst_sync;
    logic       rst_n;

    assign reset_req = PL_USER_PB[0]; //| ~locked_0;

    clock_wrapper u_wiz (
        .CLK_IN1_D_0_clk_p(CLK_IN1_D_0_clk_p),
        .CLK_IN1_D_0_clk_n(CLK_IN1_D_0_clk_n),
        .clk_out1_0       (clk),
        .locked_0         (locked_0),
        .reset_0          (PL_USER_PB[0])
    );

    always_ff @(posedge clk or posedge reset_req) begin
        if (reset_req)
            rst_sync <= 4'b0000;
        else
            rst_sync <= {rst_sync[2:0], 1'b1};
    end

    assign rst_n = rst_sync[3];
    
    logic curve_sel_core;
    logic curve_sel_sw;

    assign curve_sel_sw = PL_USER_SW[1];   // 0: secp256r1, 1: secp256k1

    // ====
    // JA_tri_io[0] = RX  (J12, JA1_P)
    // JA_tri_io[2] = TX  (H11, JA2_P)
    // ====
    logic uart_rx_raw;
    logic uart_rx_meta;
    logic uart_rx_i;
    logic uart_tx_o;

    assign uart_rx_raw  = JA_tri_io[0];

    assign JA_tri_io[0] = 1'bz;      // RX: input
    assign JA_tri_io[1] = 1'bz;      
    assign JA_tri_io[2] = uart_tx_o; // TX: output
    assign JA_tri_io[3] = 1'bz;      
    assign JA_tri_io[4] = 1'bz;      
    assign JA_tri_io[5] = 1'bz;      
    assign JA_tri_io[6] = 1'bz;      
    assign JA_tri_io[7] = 1'bz;      

    // Đồng bộ RX bất đồng bộ từ USB-UART vào clock nội bộ.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx_meta <= 1'b1;
            uart_rx_i    <= 1'b1;
        end else begin
            uart_rx_meta <= uart_rx_raw;
            uart_rx_i    <= uart_rx_meta;
        end
    end

    // ====
    // UART RX/TX
    // ====
    logic       rx_dv;
    logic [7:0] rx_byte;

    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_done;
    logic       tx_active;

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) U_RX (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_i     (uart_rx_i),
        .rx_dv_o  (rx_dv),
        .rx_byte_o(rx_byte)
    );

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) U_TX (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_dv_i    (tx_dv),
        .tx_byte_i  (tx_byte),
        .tx_active_o(tx_active),
        .tx_done_o  (tx_done),
        .tx_o       (uart_tx_o)
    );

    // ====
    // ECC core
    // ====
    logic         start_core;
    logic         busy_core;
    logic         done_core;
    logic [255:0] k_reg;
    logic [255:0] X_out, Y_out, Z_out;
    logic [255:0] X_lat, Y_lat, Z_lat;

    double_and_add #(
        .DEPTH(DEPTH)
    ) U_ECC (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start_core),
        .curve_sel (curve_sel_core),
        .k_in      (k_reg),
        .busy      (busy_core),
        .done      (done_core),
        .X_out     (X_out),
        .Y_out     (Y_out),
        .Z_out     (Z_out)
    );

    // ====
    // Comb functions
    // ====
    function automatic logic [3:0] ascii_to_nibble(input logic [7:0] c);
        begin
            if (c >= "0" && c <= "9") ascii_to_nibble = c - "0";
            else if (c >= "a" && c <= "f") ascii_to_nibble = c - "a" + 4'd10;
            else if (c >= "A" && c <= "F") ascii_to_nibble = c - "A" + 4'd10;
            else ascii_to_nibble = 4'h0;
        end
    endfunction

    function automatic logic is_hex_char(input logic [7:0] c);
        begin
            is_hex_char =
                ((c >= "0" && c <= "9") ||
                 (c >= "a" && c <= "f") ||
                 (c >= "A" && c <= "F"));
        end
    endfunction

    function automatic logic [7:0] nibble_to_ascii(input logic [3:0] n);
        begin
            if (n < 4'd10) nibble_to_ascii = "0" + n;
            else nibble_to_ascii = "A" + (n - 4'd10);
        end
    endfunction

    function automatic logic [7:0] hdr_byte(
        input logic [1:0] which,
        input logic       idx
    );
        begin
            if (idx == 1'b0) begin
                case (which)
                    2'd0: hdr_byte = "X";
                    2'd1: hdr_byte = "Y";
                    default: hdr_byte = "Z";
                endcase
            end else begin
                hdr_byte = "=";
            end
        end
    endfunction

    // ====
    // FSM UART <-> ECC
    // ====
    typedef enum logic [3:0] {
        ST_RX_IDLE,
        ST_RX_COLLECT,
        ST_START,
        ST_START_CORE,
        ST_WAIT_DONE,

        ST_TX_X_HEAD,
        ST_TX_X_DATA,
        ST_TX_X_CRLF,

        ST_TX_Y_HEAD,
        ST_TX_Y_DATA,
        ST_TX_Y_CRLF,

        ST_TX_Z_HEAD,
        ST_TX_Z_DATA,
        ST_TX_Z_CRLF
    } state_t;

    state_t state;

    logic [6:0]   rx_cnt;
    logic [6:0]   tx_cnt;
    logic [255:0] tx_data_sel;

    logic start_latched;
    logic done_latched;
    logic rx_seen;
    logic debug_echo_mode;
    assign debug_echo_mode = PL_USER_SW[0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_RX_IDLE;
            rx_cnt        <= '0;
            tx_cnt        <= '0;
            k_reg         <= '0;
            start_core    <= 1'b0;
            X_lat         <= '0;
            Y_lat         <= '0;
            Z_lat         <= '0;
            tx_dv         <= 1'b0;
            tx_byte       <= 8'h00;
            tx_data_sel   <= '0;
            start_latched <= 1'b0;
            done_latched  <= 1'b0;
            rx_seen       <= 1'b0;
            curve_sel_core <= 1'b0;
        end else begin
            start_core <= 1'b0;
            tx_dv      <= 1'b0;

            if (rx_dv)
                rx_seen <= 1'b1;

            case (state)
                ST_RX_IDLE: begin
                    rx_cnt        <= '0;
                    done_latched  <= 1'b0;
                    start_latched <= 1'b0;
                    k_reg         <= '0;

                    if (rx_dv && is_hex_char(rx_byte)) begin
                        k_reg  <= {252'd0, ascii_to_nibble(rx_byte)};
                        rx_cnt <= 7'd1;
                        state  <= ST_RX_COLLECT;
                    end
                end

                ST_RX_COLLECT: begin
                    if (rx_dv) begin
                        if (is_hex_char(rx_byte)) begin
                            k_reg <= {k_reg[251:0], ascii_to_nibble(rx_byte)};

                            if (rx_cnt == 7'd63)
                                state <= ST_START;
                            else
                                rx_cnt <= rx_cnt + 1'b1;
                        end
                    end
                end

                ST_START: begin
                    if (debug_echo_mode) begin
                        // Debug UART: gửi lại k_reg
                        X_lat  <= k_reg;
                        Y_lat  <= k_reg;
                        Z_lat  <= k_reg;
                        tx_cnt <= '0;
                        state  <= ST_TX_X_HEAD;
                    end
                    else begin
                        // Latch curve trước, clock sau mới start core
                        if (!busy_core) begin
                            curve_sel_core <= curve_sel_sw;
                            state          <= ST_START_CORE;
                        end
                    end
                end

                ST_START_CORE: begin
                    if (!busy_core) begin
                        start_core    <= 1'b1;
                        start_latched <= 1'b1;
                        state         <= ST_WAIT_DONE;
                    end
                end

                ST_WAIT_DONE: begin
                    if (done_core) begin
                        X_lat         <= X_out;
                        Y_lat         <= Y_out;
                        Z_lat         <= Z_out;
                        done_latched  <= 1'b1;
                        start_latched <= 1'b0;
                        tx_cnt        <= '0;
                        state         <= ST_TX_X_HEAD;
                    end
                end

                ST_TX_X_HEAD: begin
                    if (tx_done) begin
                        if (tx_cnt == 7'd1) begin
                            tx_cnt      <= '0;
                            tx_data_sel <= X_lat;
                            state       <= ST_TX_X_DATA;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= hdr_byte(2'd0, tx_cnt[0]);
                        tx_dv   <= 1'b1;
                    end
                end

                ST_TX_X_DATA: begin
                    if (tx_done) begin
                        tx_data_sel <= {tx_data_sel[251:0], 4'h0};
                        if (tx_cnt == 7'd63) begin
                            tx_cnt <= '0;
                            state  <= ST_TX_X_CRLF;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= nibble_to_ascii(tx_data_sel[255:252]);
                        tx_dv   <= 1'b1;
                    end
                end

                ST_TX_X_CRLF: begin
                    if (tx_done) begin
                        if (tx_cnt == 7'd1) begin
                            tx_cnt <= '0;
                            state  <= ST_TX_Y_HEAD;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= (tx_cnt == 7'd0) ? 8'h0D : 8'h0A;
                        tx_dv   <= 1'b1;
                    end
                end

                ST_TX_Y_HEAD: begin
                    if (tx_done) begin
                        if (tx_cnt == 7'd1) begin
                            tx_cnt      <= '0;
                            tx_data_sel <= Y_lat;
                            state       <= ST_TX_Y_DATA;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= hdr_byte(2'd1, tx_cnt[0]);
                        tx_dv   <= 1'b1;
                    end
                end

                ST_TX_Y_DATA: begin
                    if (tx_done) begin
                        tx_data_sel <= {tx_data_sel[251:0], 4'h0};
                        if (tx_cnt == 7'd63) begin
                            tx_cnt <= '0;
                            state  <= ST_TX_Y_CRLF;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= nibble_to_ascii(tx_data_sel[255:252]);
                        tx_dv   <= 1'b1;
                    end
                end
                
                ST_TX_Y_CRLF: begin
                    if (tx_done) begin
                        if (tx_cnt == 7'd1) begin
                            tx_cnt <= '0;
                            state  <= ST_TX_Z_HEAD;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= (tx_cnt == 7'd0) ? 8'h0D : 8'h0A;
                        tx_dv   <= 1'b1;
                    end
                end

                ST_TX_Z_HEAD: begin
                    if (tx_done) begin
                        if (tx_cnt == 7'd1) begin
                            tx_cnt      <= '0;
                            tx_data_sel <= Z_lat;
                            state       <= ST_TX_Z_DATA;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= hdr_byte(2'd2, tx_cnt[0]);
                        tx_dv   <= 1'b1;
                    end
                end

                ST_TX_Z_DATA: begin
                    if (tx_done) begin
                        tx_data_sel <= {tx_data_sel[251:0], 4'h0};
                        if (tx_cnt == 7'd63) begin
                            tx_cnt <= '0;
                            state  <= ST_TX_Z_CRLF;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= nibble_to_ascii(tx_data_sel[255:252]);
                        tx_dv   <= 1'b1;
                    end
                end

                ST_TX_Z_CRLF: begin
                    if (tx_done) begin
                        if (tx_cnt == 7'd1) begin
                            tx_cnt <= '0;
                            state  <= ST_RX_IDLE;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_byte <= (tx_cnt == 7'd0) ? 8'h0D : 8'h0A;
                        tx_dv   <= 1'b1;
                    end
                end

                default: begin
                    state <= ST_RX_IDLE;
                end
            endcase
        end
    end

    // ====
    // LED debug
    // ====
    always_comb begin
        PL_USER_LED    = 8'd0;
        PL_USER_LED[0] = busy_core;
        PL_USER_LED[1] = done_latched;
        PL_USER_LED[2] = start_latched;
        PL_USER_LED[3] = rx_seen;
        PL_USER_LED[4] = tx_active;
        PL_USER_LED[5] = locked_0;
        PL_USER_LED[6] = ~rst_n;      // đang reset
        PL_USER_LED[7] = curve_sel_core;
    end

endmodule
