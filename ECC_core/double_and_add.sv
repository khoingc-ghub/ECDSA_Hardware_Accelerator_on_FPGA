`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 10:58:15 PM
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
    parameter int DEPTH    = 4

)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,
    input  logic [SCALAR_W-1:0]  k_in,
    input  logic                 curve_sel, // 0: secp256r1, 1: secp256k1

    output logic                 busy,
    output logic                 done,

    output logic [255:0]         X_out,
    output logic [255:0]         Y_out,
    output logic [255:0]         Z_out
);

    localparam int IDX_W = $clog2(SCALAR_W);
    
    // Curve constants in Montgomery domain with R = 2^260.
    // IP = 2^256 - P, used by modular add/sub and final correction in mult_top.
    // ONE_MONT = 2^260 mod P, used as Jacobian Z = 1 in Montgomery domain.
    localparam logic [255:0] P_R1        = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam logic [255:0] IP_R1       = 256'h00000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000001;
    localparam logic [255:0] ONE_R1      = 256'h0000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000010;
    localparam logic [255:0] A_R1        = 256'hFFFFFFCF00000031000000000000000000000030FFFFFFFFFFFFFFFFFFFFFFCF;
    localparam logic [255:0] GX_R1       = 256'h8905F76B53755C669FB732B7762251075BA95FC4FEDB60179E730D418A9143C1;
    localparam logic [255:0] GY_R1       = 256'h571FF18A5885D8552E88688DD21F3258B4AB8E43A19E45CDDF25357CE95560A8;
    localparam logic [255:0] X2G_R1      = 256'h6BB32E52DCF3A3A832205038D1490D9AA6AE3C0B433827D850046D410DDD64DF;
    localparam logic [255:0] Y2G_R1      = 256'h8C577517A5B8A3AA9A8FB0E92042DBE152CD7CB7B236FF82F3648D361BEE1A57;
    localparam logic [51:0]  N0_R1       = 52'h0000000000001;

    localparam logic [255:0] P_K1        = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    localparam logic [255:0] IP_K1       = 256'h00000000000000000000000000000000000000000000000000000001000003D1;
    localparam logic [255:0] ONE_K1      = 256'h0000000000000000000000000000000000000000000000000000001000003D10;
    localparam logic [255:0] A_K1        = 256'h0000000000000000000000000000000000000000000000000000000000000000;
    localparam logic [255:0] GX_K1       = 256'h981E643E9089F48979F48C033FD129C231E295329BC66DBD7362E5AD87E22BC9;
    localparam logic [255:0] GY_K1       = 256'hF3F851FD4A582D670B6B59AAC19C1368DFC5D5D1F1DC64DB15EA6D393DBAEBEC;
    localparam logic [255:0] X2G_K1      = 256'h918623CCBA0EE23CE0B62E1E014040471354AFC88B285A04E0640CA710490BFF;
    localparam logic [255:0] Y2G_K1      = 256'hC7F7712157B93134B3A0F64BDA2CC6584FD25167DC75CE17D12D6232FACD0763;
    localparam logic [51:0]  N0_K1       = 52'h8091DD2253531;

    logic [255:0] P_MOD_r;
    logic [255:0] IP_MOD_r;
    logic [255:0] ONE_MONT_r;
    logic [255:0] A_MONT_r;
    logic [255:0] GX_MONT_r;
    logic [255:0] GY_MONT_r;
    logic [255:0] X2G_MONT_r;
    logic [255:0] Y2G_MONT_r;

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
    logic [51:0]  N0_prime_52_r;

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

        .P_mod  (P_MOD_r),
        .IP_mod (IP_MOD_r),
        .N0_prime_52  (N0_prime_52_r),

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

        .P_mod  (P_MOD_r),
        .IP_mod (IP_MOD_r),
        .N0_prime_52  (N0_prime_52_r),
        .a_curve(A_MONT_r),
        .a_is_zero(curve_sel),

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
            N0_prime_52_r <= N0_R1;

            P_MOD_r     <= P_R1;
            IP_MOD_r    <= IP_R1;
            ONE_MONT_r  <= ONE_R1;
            A_MONT_r    <= A_R1;
            GX_MONT_r   <= GX_R1;
            GY_MONT_r   <= GY_R1;
            X2G_MONT_r  <= X2G_R1;
            Y2G_MONT_r  <= Y2G_R1;

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

                        if (curve_sel) begin
                            P_MOD_r     <= P_K1;
                            IP_MOD_r    <= IP_K1;
                            ONE_MONT_r  <= ONE_K1;
                            A_MONT_r    <= A_K1;
                            GX_MONT_r   <= GX_K1;
                            GY_MONT_r   <= GY_K1;
                            X2G_MONT_r  <= X2G_K1;
                            Y2G_MONT_r  <= Y2G_K1;
                            N0_prime_52_r  <= N0_K1;
                        end else begin
                            P_MOD_r     <= P_R1;
                            IP_MOD_r    <= IP_R1;
                            ONE_MONT_r  <= ONE_R1;
                            A_MONT_r    <= A_R1;
                            GX_MONT_r   <= GX_R1;
                            GY_MONT_r   <= GY_R1;
                            X2G_MONT_r  <= X2G_R1;
                            Y2G_MONT_r  <= Y2G_R1;
                            N0_prime_52_r  <= N0_R1;
                        end

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
                        R0_X_r <= GX_MONT_r;
                        R0_Y_r <= GY_MONT_r;
                        R0_Z_r <= ONE_MONT_r;

                        R1_X_r <= X2G_MONT_r;
                        R1_Y_r <= Y2G_MONT_r;
                        R1_Z_r <= ONE_MONT_r;

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
