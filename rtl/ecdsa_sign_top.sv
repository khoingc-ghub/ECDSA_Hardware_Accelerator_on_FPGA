`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 03:47:10 PM
// Design Name: 
// Module Name: ecdsa_sign_top
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

`include "ecdsa_params.vh"
    
module ecdsa_sign_top(
    input logic clk_i,
    input logic rst_ni,
    input logic start_i,
    input logic curve_sel_i,

    input logic use_external_k_i,
    input logic [255:0] k_i,
    input logic [255:0] d_i,
    input logic [255:0] e_i,

    output logic busy_o,
    output logic done_o,
    output logic [255:0] r_o,
    output logic [255:0] s_o
);
    // select
    logic [255:0] P_sel;
    logic [255:0] IP_P_sel;
    logic [255:0] ONE_P_sel;
    logic [255:0] R2_P_sel;
    logic [255:0] A_P_sel;
    logic [255:0] GX_sel;
    logic [255:0] GY_sel;
    logic [255:0] X2G_sel;
    logic [255:0] Y2G_sel;
    logic [51:0]  N0_P_sel;
    
    logic [255:0] N_sel;
    logic [255:0] IP_N_sel;
    logic [255:0] ONE_N_sel;
    logic [255:0] R2_N_sel;
    logic [51:0]  N0_N_sel;
    
    logic a_is_zero_sel;       // for ecpd reduction
    logic a_is_zero_r;
    
    // reg
    logic [255:0] P_r;
    logic [255:0] IP_P_r;
    logic [255:0] ONE_P_r;
    logic [255:0] R2_P_r;
    logic [255:0] A_P_r;
    logic [255:0] GX_r;
    logic [255:0] GY_r;
    logic [255:0] X2G_r;
    logic [255:0] Y2G_r;
    logic [51:0]  N0_P_r;
    
    logic [255:0] N_r;
    logic [255:0] IP_N_r;
    logic [255:0] ONE_N_r;
    logic [255:0] R2_N_r;
    logic [51:0]  N0_N_r;
    
    logic [255:0] k_r;
    logic [255:0] d_r;
    logic [255:0] e_r;    
    
    // sinh nonce
    logic use_external_k_r;

    logic nonce_start;
    logic nonce_done;
    logic nonce_busy;
    logic [255:0] nonce_k;
    
    // control valid
    logic kg_start;
    logic kg_done;
    
    logic aff_start;
    logic aff_done;
    
    logic scalar_start;
    logic scalar_done;
    
    // wire connect jacobian to affine
    logic [255:0] kg_X;
    logic [255:0] kg_Y;
    logic [255:0] kg_Z;
    
    logic [255:0] aff_X;
    logic [255:0] aff_Y;
    
    // affine -> inv_shared
    logic         aff_inv_start;
    logic [255:0] aff_inv_a;
    logic [255:0] aff_inv_p;
    logic [255:0] aff_inv_M;
    
    logic         inv_busy;
    logic         inv_done;
    logic [255:0] inv_R;
    
    // affine -> mont_mul_shared
    logic         aff_mul_start;
    logic [255:0] aff_mul_A;
    logic [255:0] aff_mul_B;
    logic [255:0] aff_mul_N;
    logic [255:0] aff_mul_IP;
    logic [51:0]  aff_mul_N0;
    
    logic         mul_busy;
    logic         mul_done;
    logic [255:0] mul_R;
    
    logic         mul_start;
    logic [255:0] mul_A;
    logic [255:0] mul_B;
    logic [255:0] mul_N;
    logic [255:0] mul_IP;
    logic [51:0]  mul_N0;
    
    // reduce stage
    logic [255:0] r_red;
    logic [255:0] r_sig_r;
    logic [255:0] s_sig_r;
    
    logic         inv_start;
    logic [255:0] inv_a;
    logic [255:0] inv_p;
    logic [255:0] inv_M;
    
    // scalar stage
    logic [255:0] s_calc;
    
    logic scalar_inv_start;
    logic [255:0] scalar_inv_a;
    logic [255:0] scalar_inv_p;
    logic [255:0] scalar_inv_M;
    
    logic scalar_mul_start;
    logic [255:0] scalar_mul_A;
    logic [255:0] scalar_mul_B;
    logic [255:0] scalar_mul_N;
    logic [255:0] scalar_mul_IP;
    logic [51:0]  scalar_mul_N0;
    
    //===============//
    // rfc6979 nonce //
    //===============//
    drbg_nonce U_NONCE (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
    
        .start_i (nonce_start),
    
        .d_i     (d_r),
        .e_i     (e_r),
        .n_i     (N_r),
    
        .busy_o  (nonce_busy),
        .done_o  (nonce_done),
        .k_o     (nonce_k)
    );
    
    //================//
    // double and add //
    //================//
    double_and_add U_DOUBLE_AND_ADD (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),
    
        .start_i         (kg_start),
    
        .k_i             (k_r),
    
        .P_i             (P_r),
        .IP_i            (IP_P_r),
        .ONE_i           (ONE_P_r),
        .A_i             (A_P_r),
        .GX_i            (GX_r),
        .GY_i            (GY_r),
        .X2G_i           (X2G_r),
        .Y2G_i           (Y2G_r),
        .N0_prime_52_i   (N0_P_r),
        .a_is_zero_i     (a_is_zero_r),
        
        .busy_o          (),
        .done_o          (kg_done),
        .X_o             (kg_X),
        .Y_o             (kg_Y),
        .Z_o             (kg_Z)
    );
    
    assign r_o = r_sig_r;
    assign s_o = s_sig_r;

    //====================//
    // jacobian to affine //
    //====================//
    jacobian_to_affine_ctrl U_JAC_TO_AFF (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
    
        .start_i            (aff_start),
    
        .X_jac_i            (kg_X),
        .Y_jac_i            (kg_Y),
        .Z_jac_i            (kg_Z),
    
        .P_i                (P_r),
        .IP_i               (IP_P_r),
        .R2_i               (R2_P_r),
        .N0_prime_52_i      (N0_P_r),
    
        .inv_start_o        (aff_inv_start),
        .inv_a_o            (aff_inv_a),
        .inv_p_o            (aff_inv_p),
        .inv_M_o            (aff_inv_M),
        .inv_busy_i         (inv_busy),
        .inv_done_i         (inv_done),
        .inv_r_i            (inv_R),
    
        .mul_start_o        (aff_mul_start),
        .mul_A_o            (aff_mul_A),
        .mul_B_o            (aff_mul_B),
        .mul_N_o            (aff_mul_N),
        .mul_IP_o           (aff_mul_IP),
        .mul_N0_prime_52_o  (aff_mul_N0),
        .mul_busy_i         (mul_busy),
        .mul_done_i         (mul_done),
        .mul_R_i            (mul_R),
    
        .busy_o             (),
        .done_o             (aff_done),
        .X_aff_o            (aff_X),
        .Y_aff_o            ()
    );
    
    //=================//
    // mont mul shared //
    //=================//
    mult_wrapper #(
        .DEPTH(4)
    ) U_MONT_MUL_SHARED (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),
    
        .start_i          (mul_start),

        .A_i              (mul_A),
        .B_i              (mul_B),
        .N_i              (mul_N),
        .IP_i             (mul_IP),
        .N0_prime_52_i    (mul_N0),
            
        .busy_o           (mul_busy),
        .done_o           (mul_done),
        .R_o              (mul_R)
    );
    
    //=====//
    // inv //
    //=====//
    inv #(
        .N(256)
    ) U_INV (
        .clk    (clk_i),
        .reset  (rst_ni),
        .start  (inv_start),
    
        .a      (inv_a),
        .p      (inv_p),
        .M      (inv_M),
    
        .r      (inv_R),
        .done   (inv_done),
        .busy   (inv_busy)
    );
    
    //==============//
    // r reduction  //
    //==============//
    reduce_mod_n U_R_REDUCE (
        .x_i (aff_X),
        .n_i (N_r),
        .r_o (r_red)
    );
    
    //===============//
    // scalar n unit //
    //===============//
    scalar_n_unit U_SCALAR_N (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
    
        .start_i            (scalar_start),
    
        .k_i                (k_r),
        .d_i                (d_r),
        .e_i                (e_r),
        .r_i                (r_sig_r),
    
        .N_i                (N_r),
        .IP_N_i             (IP_N_r),
        .ONE_N_i            (ONE_N_r),
        .R2_N_i             (R2_N_r),
        .N0_N_i             (N0_N_r),
    
        .inv_start_o        (scalar_inv_start),
        .inv_a_o            (scalar_inv_a),
        .inv_p_o            (scalar_inv_p),
        .inv_M_o            (scalar_inv_M),
    
        .inv_busy_i         (inv_busy),
        .inv_done_i         (inv_done),
        .inv_r_i            (inv_R),
    
        .mul_start_o        (scalar_mul_start),
        .mul_A_o            (scalar_mul_A),
        .mul_B_o            (scalar_mul_B),
        .mul_N_o            (scalar_mul_N),
        .mul_IP_o           (scalar_mul_IP),
        .mul_N0_prime_52_o  (scalar_mul_N0),
    
        .mul_busy_i         (mul_busy),
        .mul_done_i         (mul_done),
        .mul_R_i            (mul_R),
    
        .busy_o             (),
        .done_o             (scalar_done),
        .s_o                (s_calc)
    );
    
    //select curve
    always_comb begin
        case (curve_sel_i)
            1'b1: begin
                P_sel      = P_K1;
                IP_P_sel   = IP_P_K1;
                ONE_P_sel  = ONE_P_K1;
                R2_P_sel   = R2_P_K1;
                A_P_sel    = A_P_K1;
                GX_sel     = GX_K1;
                GY_sel     = GY_K1;
                X2G_sel    = X2G_K1;
                Y2G_sel    = Y2G_K1;
                N0_P_sel   = N0_P_K1;
                a_is_zero_sel = 1'b1;

                N_sel      = N_K1;
                IP_N_sel   = IP_N_K1;
                ONE_N_sel  = ONE_N_K1;
                R2_N_sel   = R2_N_K1;
                N0_N_sel   = N0_N_K1;
            end

            default: begin
                P_sel      = P_R1;
                IP_P_sel   = IP_P_R1;
                ONE_P_sel  = ONE_P_R1;
                R2_P_sel   = R2_P_R1;
                A_P_sel    = A_P_R1;
                GX_sel     = GX_R1;
                GY_sel     = GY_R1;
                X2G_sel    = X2G_R1;
                Y2G_sel    = Y2G_R1;
                N0_P_sel   = N0_P_R1;
                a_is_zero_sel = 1'b0;

                N_sel      = N_R1;
                IP_N_sel   = IP_N_R1;
                ONE_N_sel  = ONE_N_R1;
                R2_N_sel   = R2_N_R1;
                N0_N_sel   = N0_N_R1;
            end
        endcase
    end
    
    
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_NONCE_START,
        ST_NONCE_WAIT,
        ST_KG_START,
        ST_KG_WAIT,
        ST_AFF_START,
        ST_AFF_WAIT,
        ST_R_REDUCE,
        ST_SCALAR_START,
        ST_SCALAR_WAIT,
        ST_DONE
    } state_e;
    
    state_e state_q;
    state_e state_d;
    
    assign busy_o      = (state_q != ST_IDLE);
    
    //===========//
    // main fsm  //
    //===========//
    always_comb begin
        state_d      = state_q;
        nonce_start  = 1'b0;
        kg_start     = 1'b0;
        aff_start    = 1'b0;
        scalar_start = 1'b0;
    
        done_o       = 1'b0;
    
        case (state_q)
            ST_IDLE: begin
                if (start_i) begin
                    if (use_external_k_i) begin
                        state_d = ST_KG_START;
                    end
                    else begin
                        state_d = ST_NONCE_START;
                    end
                end
            end
            
            ST_NONCE_START: begin
                nonce_start = 1'b1;
                state_d     = ST_NONCE_WAIT;
            end
            
            ST_NONCE_WAIT: begin
                if (nonce_done) begin
                    state_d = ST_KG_START;
                end
            end     
    
            ST_KG_START: begin
                kg_start = 1'b1;
                state_d  = ST_KG_WAIT;
            end
    
            ST_KG_WAIT: begin
                if (kg_done) begin
                    state_d = ST_AFF_START;
                end
            end
    
            ST_AFF_START: begin
                aff_start = 1'b1;
                state_d   = ST_AFF_WAIT;
            end
    
            ST_AFF_WAIT: begin
                if (aff_done) begin
                    state_d = ST_R_REDUCE;
                end
            end
    
            ST_R_REDUCE: begin
                state_d = ST_SCALAR_START;
            end
    
            ST_SCALAR_START: begin
                scalar_start = 1'b1;
                state_d      = ST_SCALAR_WAIT;
            end
    
            ST_SCALAR_WAIT: begin
                if (scalar_done) begin
                    state_d = ST_DONE;
                end
            end
    
            ST_DONE: begin
                done_o = 1'b1;
    
                if (!start_i) begin
                    state_d = ST_IDLE;
                end
            end
    
            default: begin
                state_d = ST_IDLE;
            end
        endcase
    end
    
    //=========//
    // inv mux //
    //=========//
    always_comb begin
        inv_start = 1'b0;
        inv_a     = '0;
        inv_p     = '0;
        inv_M     = '0;
    
        case (state_q)
            ST_AFF_START,
            ST_AFF_WAIT: begin
                inv_start = aff_inv_start;
                inv_a     = aff_inv_a;
                inv_p     = aff_inv_p;
                inv_M     = aff_inv_M;
            end
    
            ST_SCALAR_START,
            ST_SCALAR_WAIT: begin
                inv_start = scalar_inv_start;
                inv_a     = scalar_inv_a;
                inv_p     = scalar_inv_p;
                inv_M     = scalar_inv_M;
            end
    
            default: begin
                inv_start = 1'b0;
            end
        endcase
    end
    
    //=========//
    // mul mux //
    //=========//
    always_comb begin
        mul_start = 1'b0;
        mul_A     = '0;
        mul_B     = '0;
        mul_N     = '0;
        mul_IP    = '0;
        mul_N0    = '0;
    
        case (state_q)
            ST_AFF_START,
            ST_AFF_WAIT: begin
                mul_start = aff_mul_start;
                mul_A     = aff_mul_A;
                mul_B     = aff_mul_B;
                mul_N     = aff_mul_N;
                mul_IP    = aff_mul_IP;
                mul_N0    = aff_mul_N0;
            end
    
            ST_SCALAR_START,
            ST_SCALAR_WAIT: begin
                mul_start = scalar_mul_start;
                mul_A     = scalar_mul_A;
                mul_B     = scalar_mul_B;
                mul_N     = scalar_mul_N;
                mul_IP    = scalar_mul_IP;
                mul_N0    = scalar_mul_N0;
            end
    
            default: begin
                mul_start = 1'b0;
            end
        endcase
    end
    
    //=======//
    // state //
    //=======//
    /*always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= ST_IDLE;
        end
        else begin
            state_q <= state_d;
        end
    end*/
    
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= ST_IDLE;
            r_sig_r <= '0;
            s_sig_r <= '0;
        end
        else begin
            state_q <= state_d;
    
            if (state_q == ST_R_REDUCE) begin
                r_sig_r <= r_red;
            end
    
            if (scalar_done) begin
                s_sig_r <= s_calc;
            end
        end
    end
    
    //=================//
    // latch constants //
    //=================//
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            P_r      <= '0;
            IP_P_r   <= '0;
            ONE_P_r  <= '0;
            R2_P_r   <= '0;
            A_P_r    <= '0;
            GX_r     <= '0;
            GY_r     <= '0;
            X2G_r    <= '0;
            Y2G_r    <= '0;
            N0_P_r   <= '0;
            a_is_zero_r <= 1'b0;
    
            N_r      <= '0;
            IP_N_r   <= '0;
            ONE_N_r  <= '0;
            R2_N_r   <= '0;
            N0_N_r   <= '0;
    
            k_r      <= '0;
            d_r      <= '0;
            e_r      <= '0;
            use_external_k_r <= 1'b0;
        end
        else if (start_i && !busy_o) begin
            P_r      <= P_sel;
            IP_P_r   <= IP_P_sel;
            ONE_P_r  <= ONE_P_sel;
            R2_P_r   <= R2_P_sel;
            A_P_r    <= A_P_sel;
            GX_r     <= GX_sel;
            GY_r     <= GY_sel;
            X2G_r    <= X2G_sel;
            Y2G_r    <= Y2G_sel;
            N0_P_r   <= N0_P_sel;
            a_is_zero_r <= a_is_zero_sel;
    
            N_r      <= N_sel;
            IP_N_r   <= IP_N_sel;
            ONE_N_r  <= ONE_N_sel;
            R2_N_r   <= R2_N_sel;
            N0_N_r   <= N0_N_sel;
    
            use_external_k_r <= use_external_k_i;

            if (use_external_k_i) begin
                k_r <= k_i;
            end
            else begin
                k_r <= 256'h0;
            end
            
            d_r      <= d_i;
            e_r      <= e_i;
        end
        else if (state_q == ST_NONCE_WAIT && nonce_done) begin
            k_r <= nonce_k;
        end 
    end
endmodule
