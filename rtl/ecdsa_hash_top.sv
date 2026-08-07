`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/02/2026 04:47:26 PM
// Design Name: 
// Module Name: ecdsa_hash_sign_top
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



module ecdsa_hash_sign_top (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,
    input  logic         curve_sel_i,

    // 1: dùng k_i từ ngoài
    // 0: tự sinh k bằng RFC6979
    input  logic         use_external_k_i,

    // 1: dùng SHA256(msg_block_i) làm e
    // 0: dùng e_i trực tiếp như top cũ
    input  logic         use_hash_i,

    input  logic [511:0] msg_block_i,

    input  logic [255:0] k_i,
    input  logic [255:0] d_i,
    input  logic [255:0] e_i,

    output logic         busy_o,
    output logic         done_o,

    output logic [255:0] e_hash_o,
    output logic [255:0] r_o,
    output logic [255:0] s_o
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_SHA_START,
        ST_SHA_WAIT,
        ST_SIGN_START,
        ST_SIGN_WAIT,
        ST_DONE
    } state_e;

    state_e state_q;
    state_e state_d;

    logic sha_start;
    logic sha_busy;
    logic sha_done;
    logic [255:0] sha_digest;

    logic sign_start;
    logic sign_busy;
    logic sign_done;

    logic curve_sel_r;
    logic use_external_k_r;
    logic use_hash_r;

    logic [511:0] msg_block_r;
    logic [255:0] k_r;
    logic [255:0] d_r;
    logic [255:0] e_r;
    logic [255:0] e_hash_r;
    logic [255:0] e_to_sign;

    assign busy_o   = (state_q != ST_IDLE);
    assign done_o   = (state_q == ST_DONE);
    assign e_hash_o = e_hash_r;

    assign e_to_sign = use_hash_r ? e_hash_r : e_r;

    //====================//
    // sha256 one block   //
    //====================//
    sha256_one_block U_SHA256_ONE_BLOCK (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),

        .start_i  (sha_start),
        .block_i  (msg_block_r),

        .busy_o   (sha_busy),
        .done_o   (sha_done),
        .digest_o (sha_digest)
    );

    //================//
    // ecdsa sign top //
    //================//
    ecdsa_sign_top U_ECDSA_SIGN (
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),

        .start_i           (sign_start),
        .curve_sel_i       (curve_sel_r),

        .use_external_k_i  (use_external_k_r),
        .k_i               (k_r),
        .d_i               (d_r),
        .e_i               (e_to_sign),

        .busy_o            (sign_busy),
        .done_o            (sign_done),

        .r_o               (r_o),
        .s_o               (s_o)
    );

    //==========//
    // main fsm //
    //==========//
    always_comb begin
        state_d    = state_q;

        sha_start  = 1'b0;
        sign_start = 1'b0;

        case (state_q)
            ST_IDLE: begin
                if (start_i) begin
                    if (use_hash_i) begin
                        state_d = ST_SHA_START;
                    end
                    else begin
                        state_d = ST_SIGN_START;
                    end
                end
            end

            ST_SHA_START: begin
                sha_start = 1'b1;
                state_d   = ST_SHA_WAIT;
            end

            ST_SHA_WAIT: begin
                if (sha_done) begin
                    state_d = ST_SIGN_START;
                end
            end

            ST_SIGN_START: begin
                sign_start = 1'b1;
                state_d    = ST_SIGN_WAIT;
            end

            ST_SIGN_WAIT: begin
                if (sign_done) begin
                    state_d = ST_DONE;
                end
            end

            ST_DONE: begin
                if (!start_i) begin
                    state_d = ST_IDLE;
                end
            end

            default: begin
                state_d = ST_IDLE;
            end
        endcase
    end

    //===========//
    // registers //
    //===========//
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q          <= ST_IDLE;

            curve_sel_r      <= 1'b0;
            use_external_k_r <= 1'b0;
            use_hash_r       <= 1'b0;

            msg_block_r      <= '0;
            k_r              <= '0;
            d_r              <= '0;
            e_r              <= '0;
            e_hash_r         <= '0;
        end
        else begin
            state_q <= state_d;

            if (start_i && !busy_o) begin
                curve_sel_r      <= curve_sel_i;
                use_external_k_r <= use_external_k_i;
                use_hash_r       <= use_hash_i;

                msg_block_r      <= msg_block_i;
                k_r              <= k_i;
                d_r              <= d_i;
                e_r              <= e_i;
                e_hash_r         <= '0;
            end

            if (sha_done) begin
                e_hash_r <= sha_digest;
            end
        end
    end

endmodule
