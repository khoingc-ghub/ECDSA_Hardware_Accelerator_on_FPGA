`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 03:05:19 PM
// Design Name: 
// Module Name: jacobian_to_affine_ctrl
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



module jacobian_to_affine_ctrl (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,

    input  logic [255:0] X_jac_i,
    input  logic [255:0] Y_jac_i,
    input  logic [255:0] Z_jac_i,

    input  logic [255:0] P_i,
    input  logic [255:0] IP_i,
    input  logic [255:0] R2_i,
    input  logic [51:0]  N0_prime_52_i,

    output logic         inv_start_o,
    output logic [255:0] inv_a_o,
    output logic [255:0] inv_p_o,
    output logic [255:0] inv_M_o,

    input  logic         inv_busy_i,
    input  logic         inv_done_i,
    input  logic [255:0] inv_r_i,

    output logic         mul_start_o,
    output logic [255:0] mul_A_o,
    output logic [255:0] mul_B_o,
    output logic [255:0] mul_N_o,
    output logic [255:0] mul_IP_o,
    output logic [51:0]  mul_N0_prime_52_o,

    input  logic         mul_busy_i,
    input  logic         mul_done_i,
    input  logic [255:0] mul_R_i,

    output logic         busy_o,
    output logic         done_o,
    output logic [255:0] X_aff_o,
    output logic [255:0] Y_aff_o
);

    localparam logic [255:0] ONE_NORMAL = 256'd1;

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_INV_START,
        ST_INV_WAIT,
        ST_Z2_START,
        ST_Z2_WAIT,
        ST_Z3_START,
        ST_Z3_WAIT,
        ST_X_START,
        ST_X_WAIT,
        ST_Y_START,
        ST_Y_WAIT,
        ST_X_NORM_START,
        ST_X_NORM_WAIT,
        ST_Y_NORM_START,
        ST_Y_NORM_WAIT,
        ST_DONE
    } state_e;

    state_e state_q;

    logic [255:0] X_q;
    logic [255:0] Y_q;
    logic [255:0] Z_q;

    logic [255:0] P_q;
    logic [255:0] IP_q;
    logic [255:0] R2_q;
    logic [51:0]  N0_q;

    logic [255:0] z_inv_q;
    logic [255:0] z2_q;
    logic [255:0] z3_q;
    logic [255:0] x_mont_q;
    logic [255:0] y_mont_q;

    assign busy_o = (state_q != ST_IDLE);
    assign done_o = (state_q == ST_DONE);

    //=================//
    // request outputs //
    //=================//
    always_comb begin
        inv_start_o = 1'b0;
        inv_a_o     = Z_q;
        inv_p_o     = P_q;
        inv_M_o     = R2_q;

        mul_start_o          = 1'b0;
        mul_A_o              = '0;
        mul_B_o              = '0;
        mul_N_o              = P_q;
        mul_IP_o             = IP_q;
        mul_N0_prime_52_o    = N0_q;

        case (state_q)
            ST_INV_START: begin
                inv_a_o = Z_q;
                inv_p_o = P_q;
                inv_M_o = R2_q;

                if (!inv_busy_i) begin
                    inv_start_o = 1'b1;
                end
            end

            ST_Z2_START: begin
                mul_A_o = z_inv_q;
                mul_B_o = z_inv_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_Z3_START: begin
                mul_A_o = z2_q;
                mul_B_o = z_inv_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_X_START: begin
                mul_A_o = X_q;
                mul_B_o = z2_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_Y_START: begin
                mul_A_o = Y_q;
                mul_B_o = z3_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_X_NORM_START: begin
                mul_A_o = x_mont_q;
                mul_B_o = ONE_NORMAL;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_Y_NORM_START: begin
                mul_A_o = y_mont_q;
                mul_B_o = ONE_NORMAL;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            default: begin
                inv_start_o = 1'b0;
                mul_start_o = 1'b0;
            end
        endcase
    end

    //=====//
    // fsm //
    //=====//
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q  <= ST_IDLE;

            X_q      <= '0;
            Y_q      <= '0;
            Z_q      <= '0;

            P_q      <= '0;
            IP_q     <= '0;
            R2_q     <= '0;
            N0_q     <= '0;

            z_inv_q  <= '0;
            z2_q     <= '0;
            z3_q     <= '0;
            x_mont_q <= '0;
            y_mont_q <= '0;

            X_aff_o  <= '0;
            Y_aff_o  <= '0;
        end
        else begin
            case (state_q)
                ST_IDLE: begin
                    if (start_i) begin
                        X_q  <= X_jac_i;
                        Y_q  <= Y_jac_i;
                        Z_q  <= Z_jac_i;

                        P_q  <= P_i;
                        IP_q <= IP_i;
                        R2_q <= R2_i;
                        N0_q <= N0_prime_52_i;

                        state_q <= ST_INV_START;
                    end
                end

                ST_INV_START: begin
                    if (!inv_busy_i) begin
                        state_q <= ST_INV_WAIT;
                    end
                end

                ST_INV_WAIT: begin
                    if (inv_done_i) begin
                        z_inv_q <= inv_r_i;
                        state_q <= ST_Z2_START;
                    end
                end

                ST_Z2_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_Z2_WAIT;
                    end
                end

                ST_Z2_WAIT: begin
                    if (mul_done_i) begin
                        z2_q   <= mul_R_i;
                        state_q <= ST_Z3_START;
                    end
                end

                ST_Z3_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_Z3_WAIT;
                    end
                end

                ST_Z3_WAIT: begin
                    if (mul_done_i) begin
                        z3_q   <= mul_R_i;
                        state_q <= ST_X_START;
                    end
                end

                ST_X_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_X_WAIT;
                    end
                end

                ST_X_WAIT: begin
                    if (mul_done_i) begin
                        x_mont_q <= mul_R_i;
                        state_q  <= ST_Y_START;
                    end
                end

                ST_Y_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_Y_WAIT;
                    end
                end

                ST_Y_WAIT: begin
                    if (mul_done_i) begin
                        y_mont_q <= mul_R_i;
                        state_q  <= ST_X_NORM_START;
                    end
                end

                ST_X_NORM_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_X_NORM_WAIT;
                    end
                end

                ST_X_NORM_WAIT: begin
                    if (mul_done_i) begin
                        X_aff_o <= mul_R_i;
                        state_q <= ST_Y_NORM_START;
                    end
                end

                ST_Y_NORM_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_Y_NORM_WAIT;
                    end
                end

                ST_Y_NORM_WAIT: begin
                    if (mul_done_i) begin
                        Y_aff_o <= mul_R_i;
                        state_q <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    state_q <= ST_IDLE;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
