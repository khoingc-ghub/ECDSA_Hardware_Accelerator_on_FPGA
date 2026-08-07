`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 07:42:54 PM
// Design Name: 
// Module Name: hmac_sha256_msg256
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


module hmac_sha256_msg256 (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,
    input  logic [255:0] key_i,
    input  logic [255:0] msg_i,

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

        ST_OUTER0_START,
        ST_OUTER0_WAIT,

        ST_OUTER1_START,
        ST_OUTER1_WAIT,

        ST_DONE
    } state_e;

    state_e state_q;

    logic [255:0] key_q;
    logic [255:0] msg_q;
    logic [255:0] inner_digest_q;
    logic [255:0] tag_q;

    logic [511:0] key_pad_w;
    logic [511:0] inner_block0_w;
    logic [511:0] inner_block1_w;
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

    assign inner_block1_w = {
        msg_q,
        1'b1,
        191'b0,
        64'h0000000000000300
    };

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
            key_q          <= '0;
            msg_q          <= '0;
            inner_digest_q <= '0;
            tag_q          <= '0;
        end
        else begin
            case (state_q)

                ST_IDLE: begin
                    if (start_i) begin
                        key_q   <= key_i;
                        msg_q   <= msg_i;
                        state_q <= ST_INNER0_START;
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
                sha_block = inner_block1_w;

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
