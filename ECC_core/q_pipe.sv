`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 06:54:11 PM
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


module q_pipe #(
    parameter logic [51:0] N0_PRIME = 52'h0000000000001
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        in_valid,
    input  logic [51:0] A_mod_uk,
    input  logic [51:0] Bi,
    input  logic [51:0] S_lo,

    output logic        q_we,
    output logic [51:0] Q52,
    output logic [25:0] Q_lo,
    output logic [25:0] Q_hi
);

    // stage 1
    logic [103:0] prod_ab;
    logic [51:0]  ABiL_comb;

    logic         v_s1;
    logic [51:0]  ABiL_s1;
    logic [51:0]  S_lo_s1;

    // stage 2
    logic [52:0]  sum_full;
    logic [51:0]  sum52;
    logic [103:0] prod_q;
    logic [51:0]  Qi_comb;

    always_comb begin
        prod_ab   = A_mod_uk * Bi;
        ABiL_comb = prod_ab[51:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_s1    <= 1'b0;
            ABiL_s1 <= '0;
            S_lo_s1 <= '0;
        end else begin
            v_s1    <= in_valid;
            ABiL_s1 <= ABiL_comb;
            S_lo_s1 <= S_lo;
        end
    end

    always_comb begin
        sum_full = {1'b0, ABiL_s1} + {1'b0, S_lo_s1};
        sum52    = sum_full[51:0];
        prod_q   = sum52 * N0_PRIME;
        Qi_comb  = prod_q[51:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_we <= 1'b0;
            Q52  <= '0;
            Q_lo <= '0;
            Q_hi <= '0;
        end else begin
            q_we <= v_s1;
            Q52  <= Qi_comb;
            Q_lo <= Qi_comb[25:0];
            Q_hi <= Qi_comb[51:26];
        end
    end

endmodule
