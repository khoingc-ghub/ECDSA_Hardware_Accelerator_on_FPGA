`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 08:32:45 PM
// Design Name: 
// Module Name: hmac_drbg_msg
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


module hmac_drbg_msg (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,
    input  logic [1:0]   mode_i,

    input  logic [255:0] key_i,
    input  logic [255:0] V_i,
    input  logic [7:0]   prefix_i,
    input  logic [255:0] d_i,
    input  logic [255:0] e_mod_i,

    output logic         busy_o,
    output logic         done_o,
    output logic [255:0] tag_o
);

    localparam logic MODE_SHA_256 = 1'b1;

    localparam logic [511:0] IPAD_512 = {64{8'h36}};
    localparam logic [511:0] OPAD_512 = {64{8'h5c}};

    typedef enum logic [3:0] {
        ST_IDLE,

        ST_INNER0_START,
        ST_INNER0_WAIT,

        ST_INNER1_START,
        ST_INNER1_WAIT,

        ST_INNER2_START,
        ST_INNER2_WAIT,

        ST_OUTER0_START,
        ST_OUTER0_WAIT,

        ST_OUTER1_START,
        ST_OUTER1_WAIT,

        ST_DONE
    } state_e;

    state_e state_q;

    logic [1:0]   mode_q;

    logic [255:0] key_q;
    logic [255:0] V_q;
    logic [7:0]   prefix_q;
    logic [255:0] d_q;
    logic [255:0] e_mod_q;

    logic [255:0] inner_digest_q;
    logic [255:0] tag_q;

    logic [511:0] key_pad_w;
    logic [511:0] inner_block0_w;
    logic [511:0] inner_block1_short_w;
    logic [511:0] inner_block1_reject_w;
    logic [511:0] inner_block1_long_w;
    logic [511:0] inner_block2_long_w;
    logic [511:0] outer_block0_w;
    logic [511:0] outer_block1_w;

    logic         sha_init;
    logic         sha_next;
    logic [511:0] sha_block;

    logic         sha_ready;
    logic [255:0] sha_digest;
    logic         sha_digest_valid;

    assign busy_o = (state_q != ST_IDLE);
    assign done_o = (state_q == ST_DONE);
    assign tag_o  = tag_q;

    assign key_pad_w = {key_q, 256'b0};

    assign inner_block0_w = key_pad_w ^ IPAD_512;
    assign outer_block0_w = key_pad_w ^ OPAD_512;

    // mode 0:
    // HMAC(K, V)
    // msg = 32 byte
    // inner total = 64 + 32 = 96 byte = 768 bit = 0x300
    assign inner_block1_short_w = {
        V_q,
        1'b1,
        191'b0,
        64'h0000000000000300
    };

    // mode 2:
    // HMAC(K, V || prefix)
    // msg = 32 + 1 = 33 byte
    // inner total = 64 + 33 = 97 byte = 776 bit = 0x308
    assign inner_block1_reject_w = {
        V_q,
        prefix_q,
        8'h80,
        176'b0,
        64'h0000000000000308
    };

    // mode 1:
    // HMAC(K, V || prefix || d || e_mod)
    // msg = 32 + 1 + 32 + 32 = 97 byte
    // inner total = 64 + 97 = 161 byte = 1288 bit = 0x508
    //
    // block1 = V[32B] || prefix[1B] || d first 31B
    // block2 = d last 1B || e_mod[32B] || padding || length
    assign inner_block1_long_w = {
        V_q,
        prefix_q,
        d_q[255:8]
    };

    assign inner_block2_long_w = {
        d_q[7:0],
        e_mod_q,
        8'h80,
        176'b0,
        64'h0000000000000508
    };

    // outer:
    // H((K xor opad) || inner_digest)
    // outer total = 64 + 32 = 96 byte = 768 bit = 0x300
    assign outer_block1_w = {
        inner_digest_q,
        1'b1,
        191'b0,
        64'h0000000000000300
    };

    //==========//
    // sha core //
    //==========//
    sha256_core U_SHA256_CORE (
        .clk           (clk_i),
        .reset_n       (rst_ni),

        .init          (sha_init),
        .next          (sha_next),
        .mode          (MODE_SHA_256),

        .block         (sha_block),

        .ready         (sha_ready),
        .digest        (sha_digest),
        .digest_valid  (sha_digest_valid)
    );

    //=====//
    // fsm //
    //=====//
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q        <= ST_IDLE;

            mode_q         <= 2'd0;

            key_q          <= '0;
            V_q            <= '0;
            prefix_q       <= '0;
            d_q            <= '0;
            e_mod_q        <= '0;

            inner_digest_q <= '0;
            tag_q          <= '0;
        end
        else begin
            case (state_q)

                ST_IDLE: begin
                    if (start_i) begin
                        mode_q   <= mode_i;

                        key_q    <= key_i;
                        V_q      <= V_i;
                        prefix_q <= prefix_i;
                        d_q      <= d_i;
                        e_mod_q  <= e_mod_i;

                        state_q  <= ST_INNER0_START;
                    end
                end

                ST_INNER0_START: begin
                    if (sha_ready) begin
                        state_q <= ST_INNER0_WAIT;
                    end
                end

                ST_INNER0_WAIT: begin
                    state_q <= ST_INNER1_START;
                end

                ST_INNER1_START: begin
                    if (sha_ready) begin
                        state_q <= ST_INNER1_WAIT;
                    end
                end

                ST_INNER1_WAIT: begin
                    if (mode_q == 2'd1) begin
                        if (sha_ready) begin
                            state_q <= ST_INNER2_START;
                        end
                    end
                    else begin
                        if (sha_digest_valid) begin
                            inner_digest_q <= sha_digest;
                            state_q        <= ST_OUTER0_START;
                        end
                    end
                end

                ST_INNER2_START: begin
                    if (sha_ready) begin
                        state_q <= ST_INNER2_WAIT;
                    end
                end

                ST_INNER2_WAIT: begin
                    if (sha_digest_valid) begin
                        inner_digest_q <= sha_digest;
                        state_q        <= ST_OUTER0_START;
                    end
                end

                ST_OUTER0_START: begin
                    if (sha_ready) begin
                        state_q <= ST_OUTER0_WAIT;
                    end
                end

                ST_OUTER0_WAIT: begin
                    state_q <= ST_OUTER1_START;
                end

                ST_OUTER1_START: begin
                    if (sha_ready) begin
                        state_q <= ST_OUTER1_WAIT;
                    end
                end

                ST_OUTER1_WAIT: begin
                    if (sha_digest_valid) begin
                        tag_q   <= sha_digest;
                        state_q <= ST_DONE;
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

    //=============//
    // sha control //
    //=============//
    always_comb begin
        sha_init  = 1'b0;
        sha_next  = 1'b0;
        sha_block = 512'b0;

        case (state_q)

            ST_INNER0_START: begin
                sha_block = inner_block0_w;

                if (sha_ready) begin
                    sha_init = 1'b1;
                end
            end

            ST_INNER1_START: begin
                case (mode_q)
                    2'd0: begin
                        sha_block = inner_block1_short_w;
                    end

                    2'd1: begin
                        sha_block = inner_block1_long_w;
                    end

                    2'd2: begin
                        sha_block = inner_block1_reject_w;
                    end

                    default: begin
                        sha_block = inner_block1_short_w;
                    end
                endcase

                if (sha_ready) begin
                    sha_next = 1'b1;
                end
            end

            ST_INNER2_START: begin
                sha_block = inner_block2_long_w;

                if (sha_ready) begin
                    sha_next = 1'b1;
                end
            end

            ST_OUTER0_START: begin
                sha_block = outer_block0_w;

                if (sha_ready) begin
                    sha_init = 1'b1;
                end
            end

            ST_OUTER1_START: begin
                sha_block = outer_block1_w;

                if (sha_ready) begin
                    sha_next = 1'b1;
                end
            end

            default: begin
                sha_init  = 1'b0;
                sha_next  = 1'b0;
                sha_block = 512'b0;
            end

        endcase
    end

endmodule
