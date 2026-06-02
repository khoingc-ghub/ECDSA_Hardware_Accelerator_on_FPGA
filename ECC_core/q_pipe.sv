`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 11:31:55 PM
// Design Name: 
// Module Name: q_pipe
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

module q_pipe (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        in_valid,

    input  logic [51:0] A_mod_uk,
    input  logic [51:0] Bi,
    input  logic [51:0] S_lo,
    input  logic [51:0] N0_prime_52,

    output logic        q_we,
    output logic [25:0] Q_lo,
    output logic [25:0] Q_hi
);

    // ====
    // Valid pipeline
    // in_valid -> v1 -> v2 -> v3 -> q_we
    // Latency giảm 1 cycle so với bản cũ
    // ====
    logic v1, v2, v3;

    // ====
    // Stage 1: mul_ab = A * B
    // ====
    logic [103:0] mul_ab_d1;
    logic [51:0]  S_d1;
    logic [51:0]  N0_d1;

    // ====
    // Stage 2: t_val = S_lo + low52(mul_ab)
    // ====
    logic [52:0] t_val_d2;
    logic [51:0] N0_d2;

    // ====
    // Stage 3: mul_q = low52(t_val) * N0'
    // ====
    logic [103:0] mul_q_d3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1        <= 1'b0;
            v2        <= 1'b0;
            v3        <= 1'b0;
            q_we      <= 1'b0;

            mul_ab_d1 <= '0;
            S_d1      <= '0;
            N0_d1     <= '0;

            t_val_d2  <= '0;
            N0_d2     <= '0;

            mul_q_d3  <= '0;

            Q_lo      <= '0;
            Q_hi      <= '0;
        end
        else begin
            v1   <= in_valid;
            v2   <= v1;
            v3   <= v2;
            q_we <= v3;

            // ----
            // Stage 1:
            // Bỏ stage capture input.
            // DSP nhận trực tiếp A_mod_uk/Bi từ mult_mem.
            // ----
            if (in_valid) begin
                mul_ab_d1 <= A_mod_uk * Bi;
                S_d1      <= S_lo;
                N0_d1     <= N0_prime_52;
            end

            // ----
            // Stage 2:
            // ----
            if (v1) begin
                t_val_d2 <= {1'b0, S_d1} + {1'b0, mul_ab_d1[51:0]};
                N0_d2    <= N0_d1;
            end

            // ----
            // Stage 3:
            // ----
            if (v2) begin
                mul_q_d3 <= t_val_d2[51:0] * N0_d2;
            end

            // ----
            // Output:
            // ----
            if (v3) begin
                Q_lo <= mul_q_d3[25:0];
                Q_hi <= mul_q_d3[51:26];
            end
        end
    end

endmodule
