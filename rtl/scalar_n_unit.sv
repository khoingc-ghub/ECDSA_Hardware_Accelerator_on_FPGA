`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/24/2026 03:30:47 PM
// Design Name: 
// Module Name: scalar_n_unit
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



module scalar_n_unit (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,

    input  logic [255:0] k_i,
    input  logic [255:0] d_i,
    input  logic [255:0] e_i,
    input  logic [255:0] r_i,

    input  logic [255:0] N_i,
    input  logic [255:0] IP_N_i,
    input  logic [255:0] ONE_N_i,
    input  logic [255:0] R2_N_i,
    input  logic [51:0]  N0_N_i,

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
    output logic [255:0] s_o
);

    localparam logic [255:0] ONE_NORMAL = 256'd1;

    typedef enum logic [4:0] {
        ST_IDLE,

        ST_INV_START,
        ST_INV_WAIT,

        ST_D_MONT_START,
        ST_D_MONT_WAIT,

        ST_R_MONT_START,
        ST_R_MONT_WAIT,

        ST_RD_START,
        ST_RD_WAIT,

        ST_E_MONT_START,
        ST_E_MONT_WAIT,

        ST_SUM,

        ST_S_MONT_START,
        ST_S_MONT_WAIT,

        ST_S_NORM_START,
        ST_S_NORM_WAIT,

        ST_DONE
    } state_e;

    state_e state_q;

    logic [255:0] k_q;
    logic [255:0] d_q;
    logic [255:0] e_q;
    logic [255:0] r_q;

    logic [255:0] N_q;
    logic [255:0] IP_N_q;
    logic [255:0] ONE_N_q;
    logic [255:0] R2_N_q;
    logic [51:0]  N0_N_q;

    logic [255:0] kinv_mont_q;
    logic [255:0] d_mont_q;
    logic [255:0] r_mont_q;
    logic [255:0] rd_mont_q;
    logic [255:0] e_mont_q;
    logic [255:0] sum_mont_q;
    logic [255:0] s_mont_q;

    logic [255:0] sum_raw_w;
    logic [255:0] sum_sub_n_w;
    logic         sum_carry_w;
    logic         sum_no_borrow_w;

    assign busy_o = (state_q != ST_IDLE);
    assign done_o = (state_q == ST_DONE);

    //================//
    // sum raw        //
    //================//
    addsub_256_0mod U_ADD_SUM (
        .A     (e_mont_q),
        .B     (rd_mont_q),
        .SUB   (1'b0),
        .S     (sum_raw_w),
        .c_out (sum_carry_w)
    );

    //================//
    // sum - n        //
    //================//
    addsub_256_0mod U_SUB_SUM_N (
        .A     (sum_raw_w),
        .B     (N_q),
        .SUB   (1'b1),
        .S     (sum_sub_n_w),
        .c_out (sum_no_borrow_w)
    );

    //=================//
    // request outputs //
    //=================//
    always_comb begin
        inv_start_o = 1'b0;
        inv_a_o     = k_q;
        inv_p_o     = N_q;
        inv_M_o     = ONE_N_q;

        mul_start_o          = 1'b0;
        mul_A_o              = '0;
        mul_B_o              = '0;
        mul_N_o              = N_q;
        mul_IP_o             = IP_N_q;
        mul_N0_prime_52_o    = N0_N_q;

        case (state_q)
            ST_INV_START: begin
                // kinv_mont = inv(k_normal, N, ONE_N)
                //           = k^-1 * R mod N
                inv_a_o = k_q;
                inv_p_o = N_q;
                inv_M_o = ONE_N_q;

                if (!inv_busy_i) begin
                    inv_start_o = 1'b1;
                end
            end

            ST_D_MONT_START: begin
                // d_mont = MontMul(d, R2_N) = d * R mod N
                mul_A_o = d_q;
                mul_B_o = R2_N_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_R_MONT_START: begin
                // r_mont = MontMul(r, R2_N) = r * R mod N
                mul_A_o = r_q;
                mul_B_o = R2_N_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_RD_START: begin
                // rd_mont = MontMul(r_mont, d_mont)
                mul_A_o = r_mont_q;
                mul_B_o = d_mont_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_E_MONT_START: begin
                // e_mont = MontMul(e, R2_N) = e * R mod N
                mul_A_o = e_q;
                mul_B_o = R2_N_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_S_MONT_START: begin
                // s_mont = MontMul(kinv_mont, sum_mont)
                mul_A_o = kinv_mont_q;
                mul_B_o = sum_mont_q;

                if (!mul_busy_i) begin
                    mul_start_o = 1'b1;
                end
            end

            ST_S_NORM_START: begin
                // s = MontMul(s_mont, 1)
                mul_A_o = s_mont_q;
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
            state_q      <= ST_IDLE;

            k_q          <= '0;
            d_q          <= '0;
            e_q          <= '0;
            r_q          <= '0;

            N_q          <= '0;
            IP_N_q       <= '0;
            ONE_N_q      <= '0;
            R2_N_q       <= '0;
            N0_N_q       <= '0;

            kinv_mont_q  <= '0;
            d_mont_q     <= '0;
            r_mont_q     <= '0;
            rd_mont_q    <= '0;
            e_mont_q     <= '0;
            sum_mont_q   <= '0;
            s_mont_q     <= '0;

            s_o          <= '0;
        end
        else begin
            case (state_q)
                ST_IDLE: begin
                    if (start_i) begin
                        k_q     <= k_i;
                        d_q     <= d_i;
                        e_q     <= e_i;
                        r_q     <= r_i;

                        N_q     <= N_i;
                        IP_N_q  <= IP_N_i;
                        ONE_N_q <= ONE_N_i;
                        R2_N_q  <= R2_N_i;
                        N0_N_q  <= N0_N_i;

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
                        kinv_mont_q <= inv_r_i;
                        state_q     <= ST_D_MONT_START;
                    end
                end

                ST_D_MONT_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_D_MONT_WAIT;
                    end
                end

                ST_D_MONT_WAIT: begin
                    if (mul_done_i) begin
                        d_mont_q <= mul_R_i;
                        state_q  <= ST_R_MONT_START;
                    end
                end

                ST_R_MONT_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_R_MONT_WAIT;
                    end
                end

                ST_R_MONT_WAIT: begin
                    if (mul_done_i) begin
                        r_mont_q <= mul_R_i;
                        state_q  <= ST_RD_START;
                    end
                end

                ST_RD_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_RD_WAIT;
                    end
                end

                ST_RD_WAIT: begin
                    if (mul_done_i) begin
                        rd_mont_q <= mul_R_i;
                        state_q   <= ST_E_MONT_START;
                    end
                end

                ST_E_MONT_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_E_MONT_WAIT;
                    end
                end

                ST_E_MONT_WAIT: begin
                    if (mul_done_i) begin
                        e_mont_q <= mul_R_i;
                        state_q  <= ST_SUM;
                    end
                end

                ST_SUM: begin
                    // sum_mont = e_mont + rd_mont mod N
                    if (sum_carry_w || sum_no_borrow_w) begin
                        sum_mont_q <= sum_sub_n_w;
                    end
                    else begin
                        sum_mont_q <= sum_raw_w;
                    end

                    state_q <= ST_S_MONT_START;
                end

                ST_S_MONT_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_S_MONT_WAIT;
                    end
                end

                ST_S_MONT_WAIT: begin
                    if (mul_done_i) begin
                        s_mont_q <= mul_R_i;
                        state_q  <= ST_S_NORM_START;
                    end
                end

                ST_S_NORM_START: begin
                    if (!mul_busy_i) begin
                        state_q <= ST_S_NORM_WAIT;
                    end
                end

                ST_S_NORM_WAIT: begin
                    if (mul_done_i) begin
                        s_o     <= mul_R_i;
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
