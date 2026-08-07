`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/31/2026 11:23:07 AM
// Design Name: 
// Module Name: drbg_nonce
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


module drbg_nonce (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,

    input  logic [255:0] d_i,
    input  logic [255:0] e_i,
    input  logic [255:0] n_i,

    output logic         busy_o,
    output logic         done_o,
    output logic [255:0] k_o
);

    typedef enum logic [4:0] {
        ST_IDLE,

        ST_UPD0_K_START,
        ST_UPD0_K_WAIT,

        ST_UPD0_V_START,
        ST_UPD0_V_WAIT,

        ST_UPD1_K_START,
        ST_UPD1_K_WAIT,

        ST_UPD1_V_START,
        ST_UPD1_V_WAIT,

        ST_GEN_START,
        ST_GEN_WAIT,

        ST_CHECK,

        ST_REJ_K_START,
        ST_REJ_K_WAIT,

        ST_REJ_V_START,
        ST_REJ_V_WAIT,

        ST_DONE
    } state_e;

    state_e state_q;

    logic [255:0] d_q;
    logic [255:0] e_q;
    logic [255:0] n_q;

    logic [255:0] K_q;
    logic [255:0] V_q;
    logic [255:0] k_q;

    logic [255:0] e_sub_n_w;
    logic         e_ge_n_w;
    logic [255:0] e_mod_w;
    logic [255:0] e_mod_q;

    logic [255:0] k_sub_n_w;
    logic         k_ge_n_w;

    logic         hmac_start;
    logic [1:0]   hmac_mode;
    logic [7:0]   hmac_prefix;
    logic         hmac_done;
    logic [255:0] hmac_tag;

    assign busy_o = (state_q != ST_IDLE);
    assign done_o = (state_q == ST_DONE);
    assign k_o    = k_q;

    // e_mod = e mod n
    // Vì e và n đều 256-bit, với 2 curve này chỉ cần trừ n một lần.
    addsub_256_0mod U_SUB_E_N (
        .A     (e_i),
        .B     (n_i),
        .SUB   (1'b1),
        .S     (e_sub_n_w),
        .c_out (e_ge_n_w)
    );

    assign e_mod_w = e_ge_n_w ? e_sub_n_w : e_i;

    // check V >= n
    addsub_256_0mod U_SUB_K_N (
        .A     (V_q),
        .B     (n_q),
        .SUB   (1'b1),
        .S     (k_sub_n_w),
        .c_out (k_ge_n_w)
    );

    //======//
    // hmac //
    //======//
    hmac_drbg_msg U_HMAC (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),

        .start_i   (hmac_start),
        .mode_i    (hmac_mode),

        .key_i     (K_q),
        .V_i       (V_q),
        .prefix_i  (hmac_prefix),
        .d_i       (d_q),
        .e_mod_i   (e_mod_q),

        .busy_o    (),
        .done_o    (hmac_done),
        .tag_o     (hmac_tag)
    );

    //=====//
    // fsm //
    //=====//
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= ST_IDLE;

            d_q     <= '0;
            e_q     <= '0;
            n_q     <= '0;
            e_mod_q <= '0;

            K_q     <= '0;
            V_q     <= '0;
            k_q     <= '0;
        end
        else begin
            case (state_q)

                ST_IDLE: begin
                    if (start_i) begin
                        d_q     <= d_i;
                        e_q     <= e_i;
                        n_q     <= n_i;
                        e_mod_q <= e_mod_w;

                        K_q     <= 256'h0;
                        V_q     <= {32{8'h01}};
                        k_q     <= 256'h0;

                        state_q <= ST_UPD0_K_START;
                    end
                end

                // K = HMAC(K, V || 00 || d || e_mod)
                ST_UPD0_K_START: begin
                    state_q <= ST_UPD0_K_WAIT;
                end

                ST_UPD0_K_WAIT: begin
                    if (hmac_done) begin
                        K_q     <= hmac_tag;
                        state_q <= ST_UPD0_V_START;
                    end
                end

                // V = HMAC(K, V)
                ST_UPD0_V_START: begin
                    state_q <= ST_UPD0_V_WAIT;
                end

                ST_UPD0_V_WAIT: begin
                    if (hmac_done) begin
                        V_q     <= hmac_tag;
                        state_q <= ST_UPD1_K_START;
                    end
                end

                // K = HMAC(K, V || 01 || d || e_mod)
                ST_UPD1_K_START: begin
                    state_q <= ST_UPD1_K_WAIT;
                end

                ST_UPD1_K_WAIT: begin
                    if (hmac_done) begin
                        K_q     <= hmac_tag;
                        state_q <= ST_UPD1_V_START;
                    end
                end

                // V = HMAC(K, V)
                ST_UPD1_V_START: begin
                    state_q <= ST_UPD1_V_WAIT;
                end

                ST_UPD1_V_WAIT: begin
                    if (hmac_done) begin
                        V_q     <= hmac_tag;
                        state_q <= ST_GEN_START;
                    end
                end

                // Generate: V = HMAC(K, V)
                ST_GEN_START: begin
                    state_q <= ST_GEN_WAIT;
                end

                ST_GEN_WAIT: begin
                    if (hmac_done) begin
                        V_q     <= hmac_tag;
                        state_q <= ST_CHECK;
                    end
                end

                // Accept nếu 1 <= V < n
                ST_CHECK: begin
                    if ((V_q != 256'h0) && !k_ge_n_w) begin
                        k_q     <= V_q;
                        state_q <= ST_DONE;
                    end
                    else begin
                        state_q <= ST_REJ_K_START;
                    end
                end

                // Reject:
                // K = HMAC(K, V || 00)
                ST_REJ_K_START: begin
                    state_q <= ST_REJ_K_WAIT;
                end

                ST_REJ_K_WAIT: begin
                    if (hmac_done) begin
                        K_q     <= hmac_tag;
                        state_q <= ST_REJ_V_START;
                    end
                end

                // V = HMAC(K, V)
                ST_REJ_V_START: begin
                    state_q <= ST_REJ_V_WAIT;
                end

                ST_REJ_V_WAIT: begin
                    if (hmac_done) begin
                        V_q     <= hmac_tag;
                        state_q <= ST_GEN_START;
                    end
                end

                ST_DONE: begin
                    if (!start_i) begin
                        state_q <= ST_IDLE;
                    end
                end

                default: begin
                    state_q <= ST_IDLE;
                end

            endcase
        end
    end

    //==============//
    // hmac control //
    //==============//
    always_comb begin
        hmac_start  = 1'b0;
        hmac_mode   = 2'd0;
        hmac_prefix = 8'h00;

        case (state_q)

            ST_UPD0_K_START: begin
                hmac_start  = 1'b1;
                hmac_mode   = 2'd1;
                hmac_prefix = 8'h00;
            end

            ST_UPD0_V_START: begin
                hmac_start  = 1'b1;
                hmac_mode   = 2'd0;
                hmac_prefix = 8'h00;
            end

            ST_UPD1_K_START: begin
                hmac_start  = 1'b1;
                hmac_mode   = 2'd1;
                hmac_prefix = 8'h01;
            end

            ST_UPD1_V_START: begin
                hmac_start  = 1'b1;
                hmac_mode   = 2'd0;
                hmac_prefix = 8'h00;
            end

            ST_GEN_START: begin
                hmac_start  = 1'b1;
                hmac_mode   = 2'd0;
                hmac_prefix = 8'h00;
            end

            ST_REJ_K_START: begin
                hmac_start  = 1'b1;
                hmac_mode   = 2'd2;
                hmac_prefix = 8'h00;
            end

            ST_REJ_V_START: begin
                hmac_start  = 1'b1;
                hmac_mode   = 2'd0;
                hmac_prefix = 8'h00;
            end

            default: begin
                hmac_start  = 1'b0;
                hmac_mode   = 2'd0;
                hmac_prefix = 8'h00;
            end

        endcase
    end

endmodule
