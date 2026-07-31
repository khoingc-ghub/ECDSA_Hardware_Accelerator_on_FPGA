`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2026 03:49:50 PM
// Design Name: 
// Module Name: mult_mem
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


module mult_mem #(
    parameter int DEPTH = 4
)(
    input  logic clk,
    input  logic rst_n,

    // control
    input  logic start,
    output logic busy,
    output logic mem_valid,
    input  logic batch_done,

    // input stream
    input  logic [255:0] A_in,
    input  logic [255:0] B_in,
    input  logic [255:0] N_in,

    // read address cho AB
    input  logic [3:0] x   [16],
    input  logic [2:0] y   [16],

    // read address cho q_pipe
    input  logic [1:0] x_p,
    input  logic [2:0] y_p,

    // read address cho NQ

    // write-back S từ top
    input  logic         s_pack_we,
    input  logic [3:0]   s_pack_x,
    input  logic [271:0] s256_in,

    // outputs AB
    output logic [16:0] Aseg_o [16],
    output logic [16:0] Sseg_o [16],
    output logic [25:0] B_lo_o [16],
    output logic [25:0] B_hi_o [16],

    // outputs q_pipe
    output logic [51:0] A52_p,
    output logic [51:0] B52_p,
    output logic [51:0] S52_p,

    // outputs NQ
    output logic [16:0] Nseg_q_o [16]
);

    // =====================================================
    // memory banks
    // =====================================================
    logic [16:0] Aseg_mem [DEPTH][16];
    logic [16:0] Sseg_mem [DEPTH][16];
    logic [16:0] Nseg_mem [16];

    logic [25:0] B_lo_mem [DEPTH][5];
    logic [25:0] B_hi_mem [DEPTH][5];

    logic [3:0] wr_cnt;

    integer i, j, w, t_s;

    // -----------------------------------------------------
    // mem_valid
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_valid <= 1'b0;
        else if (batch_done)
            mem_valid <= 1'b0;
        else if (start)
            mem_valid <= 1'b1;
    end

    // -----------------------------------------------------
    // wr_cnt / busy
    // busy của mem: đã nạp đủ DEPTH slot
    // top hiện không dùng tín hiệu này để chặn chạy
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_cnt <= '0;
            busy   <= 1'b0;
        end
        else if (batch_done) begin
            wr_cnt <= '0;
            busy   <= 1'b0;
        end
        else begin
            if (start && !busy) begin
                if (wr_cnt == DEPTH-1)
                    busy <= 1'b1;
                else
                    wr_cnt <= wr_cnt + 1'b1;
            end
        end
    end

    // -----------------------------------------------------
    // WRITE A / N / A52 / B
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    Aseg_mem[i][j] <= '0;
                end
                for (w = 0; w < 5; w = w + 1) begin
                    B_lo_mem[i][w] <= '0;
                    B_hi_mem[i][w] <= '0;
                end
            end
            for (j = 0; j < 16; j = j + 1)
                Nseg_mem[j] <= '0;
        end
        else if (batch_done) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    Aseg_mem[i][j] <= '0;
                end
                for (w = 0; w < 5; w = w + 1) begin
                    B_lo_mem[i][w] <= '0;
                    B_hi_mem[i][w] <= '0;
                end
            end
            for (j = 0; j < 16; j = j + 1)
                Nseg_mem[j] <= '0;
        end
        else if (start && !busy) begin
            for (i = 0; i < 15; i = i + 1) begin
                Aseg_mem[wr_cnt][i] <= A_in[17*i +: 17];
            end

            Aseg_mem[wr_cnt][15] <= {16'b0, A_in[255]};

            for (i = 0; i < 15; i = i + 1) begin
                Nseg_mem[i] <= N_in[17*i +: 17];
            end

            Nseg_mem[15] <= {16'b0, N_in[255]};

            for (j = 0; j < 4; j = j + 1) begin
                B_lo_mem[wr_cnt][j] <= B_in[52*j      +: 26];
                B_hi_mem[wr_cnt][j] <= B_in[52*j + 26 +: 26];
            end

            B_lo_mem[wr_cnt][4] <= B_in[233:208];
            B_hi_mem[wr_cnt][4] <= {4'b0, B_in[255:234]};
        end
    end

    // -----------------------------------------------------
    // WRITE S
    // - S ban đầu luôn bằng 0 cho mỗi phép nhân
    // - các vòng sau dùng S mới ghi ngược từ stage s_pack
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1)
                    Sseg_mem[i][j] <= '0;
            end
        end
        else if (batch_done) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1)
                    Sseg_mem[i][j] <= '0;
            end
        end
        else begin
            if (start && !busy) begin
                // S0 của Montgomery accumulation luôn khởi tạo bằng 0.
                // Các giá trị S cho y kế tiếp sẽ được ghi bằng s_pack_we.
                for (t_s = 0; t_s < 16; t_s = t_s + 1)
                    Sseg_mem[wr_cnt][t_s] <= '0;
            end

            if (s_pack_we && (s_pack_x < DEPTH)) begin
                for (t_s = 0; t_s < 16; t_s = t_s + 1)
                    Sseg_mem[s_pack_x][t_s] <= s256_in[17*t_s +: 17];
            end
        end
    end

    // -----------------------------------------------------
    // READ cho AB và NQ
    // -----------------------------------------------------
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin : GEN_READ
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    Aseg_o[k]   <= '0;
                    Sseg_o[k]   <= '0;
                    B_lo_o[k]   <= '0;
                    B_hi_o[k]   <= '0;
                    Nseg_q_o[k] <= '0;
                end else begin
                    if ((x[k] < DEPTH) && (y[k] < 3'd5)) begin
                        Aseg_o[k] <= Aseg_mem[x[k]][k];
                        Sseg_o[k] <= Sseg_mem[x[k]][k];
                        B_lo_o[k] <= B_lo_mem[x[k]][y[k]];
                        B_hi_o[k] <= B_hi_mem[x[k]][y[k]];
                    end else begin
                        Aseg_o[k] <= '0;
                        Sseg_o[k] <= '0;
                        B_lo_o[k] <= '0;
                        B_hi_o[k] <= '0;
                    end

                    // N dùng chung cả batch, chỉ cần register ra để cắt timing
                    Nseg_q_o[k] <= Nseg_mem[k];
                end
            end
        end
    endgenerate

    // -----------------------------------------------------
    // READ cho q_pipe
    // -----------------------------------------------------
    always_comb begin
        A52_p = '0;
        B52_p = '0;
        S52_p = '0;

        if (x_p < DEPTH) begin
            // A[51:0] = {A[51], A[50:34], A[33:17], A[16:0]}
            A52_p = {
                Aseg_mem[x_p][3][0],
                Aseg_mem[x_p][2],
                Aseg_mem[x_p][1],
                Aseg_mem[x_p][0]
            };

            // B word 52-bit ghép lại từ hi/lo
            B52_p = {
                B_hi_mem[x_p][y_p],
                B_lo_mem[x_p][y_p]
            };

            // S[51:0] ghép từ Sseg
            S52_p = {
                Sseg_mem[x_p][3][0],
                Sseg_mem[x_p][2],
                Sseg_mem[x_p][1],
                Sseg_mem[x_p][0]
            };
        end
    end

endmodule
