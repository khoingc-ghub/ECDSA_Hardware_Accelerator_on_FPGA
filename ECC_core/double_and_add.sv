`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/10/2026 08:25:06 PM
// Design Name: 
// Module Name: double_and_add
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





module double_and_add #(
    parameter int SCALAR_W = 256,
    parameter int DEPTH    = 16

)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,
    input  logic [SCALAR_W-1:0]  k_in,

    output logic                 busy,
    output logic                 done,

    output logic [255:0]         X_out,
    output logic [255:0]         Y_out,
    output logic [255:0]         Z_out
);

    localparam int IDX_W = $clog2(SCALAR_W);
    // ============================================================
    // secp256r1 constants in Montgomery domain
    // ============================================================
    localparam logic [255:0] P_MOD     = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam logic [255:0] ONE_MONT  = 256'h0000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000010;
    localparam logic [255:0] A_MONT    = 256'hFFFFFFCF00000031000000000000000000000030FFFFFFFFFFFFFFFFFFFFFFCF;

    localparam logic [255:0] GX_MONT   = 256'h8905F76B53755C669FB732B7762251075BA95FC4FEDB60179E730D418A9143C1;
    localparam logic [255:0] GY_MONT   = 256'h571FF18A5885D8552E88688DD21F3258B4AB8E43A19E45CDDF25357CE95560A8;

    localparam logic [255:0] X2G_MONT  = 256'h6BB32E52DCF3A3A832205038D1490D9AA6AE3C0B433827D850046D410DDD64DF;
    localparam logic [255:0] Y2G_MONT  = 256'h8C577517A5B8A3AA9A8FB0E92042DBE152CD7CB7B236FF82F3648D361BEE1A57;

    typedef enum logic [2:0] {
        ST_IDLE   = 3'd0,
        ST_INIT   = 3'd1,
        ST_PREP   = 3'd2,
        ST_START  = 3'd3,
        ST_WAIT   = 3'd4,
        ST_UPDATE = 3'd5,
        ST_DONE   = 3'd6
    } state_t;

    state_t state;

    logic [SCALAR_W-1:0] k_r;
    logic [IDX_W-1:0]    bit_idx;
    logic [IDX_W-1:0]    msb_idx_w;
    logic                current_bit_r;

    logic [255:0] R0_X_r, R0_Y_r, R0_Z_r;
    logic [255:0] R1_X_r, R1_Y_r, R1_Z_r;

    logic [255:0] add_X1_r, add_Y1_r, add_Z1_r;
    logic [255:0] add_X2_r, add_Y2_r, add_Z2_r;

    logic [255:0] dbl_X1_r, dbl_Y1_r, dbl_Z1_r;

    logic         ecpa_start, ecpa_busy, ecpa_done;
    logic [255:0] ecpa_X3_out, ecpa_Y3_out, ecpa_Z3_out;

    logic         ecpd_start, ecpd_busy, ecpd_done;
    logic [255:0] ecpd_X3_out, ecpd_Y3_out, ecpd_Z3_out;
    logic ecpa_done_seen_r, ecpd_done_seen_r;

    function automatic [IDX_W-1:0] find_msb_idx (
        input logic [SCALAR_W-1:0] val
    );
        integer i;
        logic found;
        begin
            find_msb_idx = '0;
            found        = 1'b0;
            for (i = SCALAR_W-1; i >= 0; i = i - 1) begin
                if (!found && val[i]) begin
                    find_msb_idx = i[IDX_W-1:0];
                    found        = 1'b1;
                end
            end
        end
    endfunction

    assign msb_idx_w = find_msb_idx(k_r);

    assign X_out = R0_X_r;
    assign Y_out = R0_Y_r;
    assign Z_out = R0_Z_r;

    ecpa #(
        .DEPTH(DEPTH)
    ) U_ECPA (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (ecpa_start),

        .P_mod  (P_MOD),

        .X1_in  (add_X1_r),
        .Y1_in  (add_Y1_r),
        .Z1_in  (add_Z1_r),

        .X2_in  (add_X2_r),
        .Y2_in  (add_Y2_r),
        .Z2_in  (add_Z2_r),

        .busy   (ecpa_busy),
        .done   (ecpa_done),

        .X3_out (ecpa_X3_out),
        .Y3_out (ecpa_Y3_out),
        .Z3_out (ecpa_Z3_out)
    );

    ecpd #(
        .DEPTH(DEPTH)
    ) U_ECPD (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (ecpd_start),

        .P_mod  (P_MOD),
        .a_curve(A_MONT),

        .X1_in  (dbl_X1_r),
        .Y1_in  (dbl_Y1_r),
        .Z1_in  (dbl_Z1_r),

        .busy   (ecpd_busy),
        .done   (ecpd_done),

        .X3_out (ecpd_X3_out),
        .Y3_out (ecpd_Y3_out),
        .Z3_out (ecpd_Z3_out)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;

            k_r           <= '0;
            bit_idx       <= '0;
            current_bit_r <= 1'b0;

            R0_X_r        <= '0;
            R0_Y_r        <= '0;
            R0_Z_r        <= '0;
            R1_X_r        <= '0;
            R1_Y_r        <= '0;
            R1_Z_r        <= '0;

            add_X1_r      <= '0;
            add_Y1_r      <= '0;
            add_Z1_r      <= '0;
            add_X2_r      <= '0;
            add_Y2_r      <= '0;
            add_Z2_r      <= '0;

            dbl_X1_r      <= '0;
            dbl_Y1_r      <= '0;
            dbl_Z1_r      <= '0;

            ecpa_start    <= 1'b0;
            ecpd_start    <= 1'b0;
            ecpa_done_seen_r <= 1'b0;
            ecpd_done_seen_r <= 1'b0;
        end else begin
            done       <= 1'b0;
            ecpa_start <= 1'b0;
            ecpd_start <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        k_r  <= k_in;
                        state <= ST_INIT;
                    end
                end

                ST_INIT: begin
                    if (k_r == {SCALAR_W{1'b0}}) begin
                        R0_X_r <= 256'd0;
                        R0_Y_r <= 256'd0;
                        R0_Z_r <= 256'd0;

                        R1_X_r <= 256'd0;
                        R1_Y_r <= 256'd0;
                        R1_Z_r <= 256'd0;

                        state  <= ST_DONE;
                    end else begin
                        R0_X_r <= GX_MONT;
                        R0_Y_r <= GY_MONT;
                        R0_Z_r <= ONE_MONT;

                        R1_X_r <= X2G_MONT;
                        R1_Y_r <= Y2G_MONT;
                        R1_Z_r <= ONE_MONT;

                        if (msb_idx_w == {IDX_W{1'b0}}) begin
                            state <= ST_DONE;
                        end else begin
                            bit_idx <= msb_idx_w - 1'b1;
                            state   <= ST_PREP;
                        end
                    end
                end

                ST_PREP: begin
                    ecpa_done_seen_r <= 1'b0;
                    ecpd_done_seen_r <= 1'b0;

                    current_bit_r <= k_r[bit_idx];

                    add_X1_r <= R0_X_r;
                    add_Y1_r <= R0_Y_r;
                    add_Z1_r <= R0_Z_r;

                    add_X2_r <= R1_X_r;
                    add_Y2_r <= R1_Y_r;
                    add_Z2_r <= R1_Z_r;

                    if (k_r[bit_idx] == 1'b0) begin
                        dbl_X1_r <= R0_X_r;
                        dbl_Y1_r <= R0_Y_r;
                        dbl_Z1_r <= R0_Z_r;
                    end else begin
                        dbl_X1_r <= R1_X_r;
                        dbl_Y1_r <= R1_Y_r;
                        dbl_Z1_r <= R1_Z_r;
                    end

                    state <= ST_START;
                end

                ST_START: begin
                    ecpa_start <= 1'b1;
                    ecpd_start <= 1'b1;
                    state      <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (ecpa_done)
                        ecpa_done_seen_r <= 1'b1;

                    if (ecpd_done)
                        ecpd_done_seen_r <= 1'b1;

                    if ( (ecpa_done_seen_r || ecpa_done) &&
                        (ecpd_done_seen_r || ecpd_done) ) begin
                        state <= ST_UPDATE;
                    end
                end

                ST_UPDATE: begin
                    if (current_bit_r == 1'b0) begin
                        // bit = 0:
                        // R1 = R0 + R1
                        // R0 = 2R0
                        R1_X_r <= ecpa_X3_out;
                        R1_Y_r <= ecpa_Y3_out;
                        R1_Z_r <= ecpa_Z3_out;

                        R0_X_r <= ecpd_X3_out;
                        R0_Y_r <= ecpd_Y3_out;
                        R0_Z_r <= ecpd_Z3_out;
                    end else begin
                        // bit = 1:
                        // R0 = R0 + R1
                        // R1 = 2R1
                        R0_X_r <= ecpa_X3_out;
                        R0_Y_r <= ecpa_Y3_out;
                        R0_Z_r <= ecpa_Z3_out;

                        R1_X_r <= ecpd_X3_out;
                        R1_Y_r <= ecpd_Y3_out;
                        R1_Z_r <= ecpd_Z3_out;
                    end

                    if (bit_idx == 0) begin
                        state <= ST_DONE;
                    end else begin
                        bit_idx <= bit_idx - 1'b1;
                        state   <= ST_PREP;
                    end
                end

                ST_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
