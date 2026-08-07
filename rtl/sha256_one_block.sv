`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 05:57:06 PM
// Design Name: 
// Module Name: sha256_one_block
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


module sha256_one_block (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,
    input  logic [511:0] block_i,

    output logic         busy_o,
    output logic         done_o,
    output logic [255:0] digest_o
);

    localparam logic MODE_SHA_256 = 1'b1;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_START,
        ST_WAIT,
        ST_DONE
    } state_e;

    state_e state_q;

    logic         sha_init;
    logic         sha_next;
    logic [511:0] sha_block;

    logic         sha_ready;
    logic [255:0] sha_digest;
    logic         sha_digest_valid;

    logic [511:0] block_q;
    logic [255:0] digest_q;

    assign busy_o   = (state_q != ST_IDLE);
    assign done_o   = (state_q == ST_DONE);
    assign digest_o = digest_q;

    assign sha_next  = 1'b0;
    assign sha_block = block_q;

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
            state_q  <= ST_IDLE;
            block_q  <= '0;
            digest_q <= '0;
        end
        else begin
            case (state_q)

                ST_IDLE: begin
                    if (start_i) begin
                        block_q <= block_i;
                        state_q <= ST_START;
                    end
                end

                ST_START: begin
                    if (sha_ready) begin
                        state_q <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (sha_digest_valid) begin
                        digest_q <= sha_digest;
                        state_q  <= ST_DONE;
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
        sha_init = 1'b0;

        case (state_q)
            ST_START: begin
                if (sha_ready) begin
                    sha_init = 1'b1;
                end
            end

            default: begin
                sha_init = 1'b0;
            end
        endcase
    end

endmodule
