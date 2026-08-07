`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2026 05:48:38 PM
// Design Name: 
// Module Name: mult_wrapper
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



module mult_wrapper #(
    parameter int DEPTH = 4
)(
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,

    input  logic [255:0] A_i,
    input  logic [255:0] B_i,
    input  logic [255:0] N_i,
    input  logic [255:0] IP_i,
    input  logic [51:0]  N0_prime_52_i,

    output logic         busy_o,
    output logic         done_o,
    output logic [255:0] R_o
);

    logic         mt_start;
    logic         mt_busy;
    logic [255:0] mt_result;
    logic         mt_result_valid;
    logic [1:0]   mt_result_idx;

    logic [255:0] A_r;
    logic [255:0] B_r;
    logic [255:0] N_r;
    logic [255:0] IP_r;
    logic [51:0]  N0_r;

    logic result_seen_r;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_WAIT,
        ST_DONE
    } state_e;

    state_e state_q;

    //================//
    // mult_top       //
    //================//
    mult_top #(
        .DEPTH(DEPTH)
    ) U_MONT_MUL (
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),

        .start_i           (mt_start),
        .A_i               (A_r),
        .B_i               (B_r),
        .N_i               (N_r),
        .IP_mod_i          (IP_r),
        .N0_prime_52_i     (N0_r),

        .busy_o            (mt_busy),

        .result_o          (mt_result),
        .result_valid_o    (mt_result_valid),
        .result_idx_o      (mt_result_idx)
    );

    //=====//
    // fsm //
    //=====//
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q       <= ST_IDLE;
            mt_start      <= 1'b0;
            busy_o        <= 1'b0;
            done_o        <= 1'b0;
            R_o           <= '0;
            A_r           <= '0;
            B_r           <= '0;
            N_r           <= '0;
            IP_r          <= '0;
            N0_r          <= '0;
            result_seen_r <= 1'b0;
        end
        else begin
            mt_start <= 1'b0;
            done_o   <= 1'b0;

            case (state_q)
                ST_IDLE: begin
                    busy_o        <= 1'b0;
                    result_seen_r <= 1'b0;

                    if (start_i) begin
                        busy_o   <= 1'b1;

                        A_r      <= A_i;
                        B_r      <= B_i;
                        N_r      <= N_i;
                        IP_r     <= IP_i;
                        N0_r     <= N0_prime_52_i;

                        mt_start <= 1'b1;
                        state_q  <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (mt_result_valid && (mt_result_idx == 2'd0)) begin
                        R_o           <= mt_result;
                        result_seen_r <= 1'b1;
                    end

                    if (result_seen_r && !mt_busy) begin
                        state_q <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    busy_o  <= 1'b0;
                    done_o  <= 1'b1;
                    state_q <= ST_IDLE;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
