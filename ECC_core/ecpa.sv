`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 08:28:48 PM
// Design Name: 
// Module Name: ecpa
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


module ecpa #(
    parameter int DEPTH = 16
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,

    input  logic [255:0] P_mod,

    input  logic [255:0] X1_in,
    input  logic [255:0] Y1_in,
    input  logic [255:0] Z1_in,

    input  logic [255:0] X2_in,
    input  logic [255:0] Y2_in,
    input  logic [255:0] Z2_in,

    output logic         busy,
    output logic         done,

    output logic [255:0] X3_out,
    output logic [255:0] Y3_out,
    output logic [255:0] Z3_out
);

    typedef enum logic [5:0] {
        ST_IDLE          = 6'd0,

        ST_BA_START      = 6'd1,
        ST_BA_WAIT       = 6'd2,

        ST_BB_START      = 6'd3,
        ST_BB_WAIT       = 6'd4,

        ST_BC_START      = 6'd5,
        ST_BC_WAIT       = 6'd6,

        ST_H_LOAD        = 6'd7,
        ST_H_WAIT        = 6'd8,
        ST_R_LOAD        = 6'd9,
        ST_R_WAIT        = 6'd10,

        ST_BE_START      = 6'd11,
        ST_BE_WAIT       = 6'd12,

        ST_BF_START      = 6'd13,
        ST_BF_WAIT       = 6'd14,

        ST_2V_LOAD       = 6'd15,
        ST_2V_WAIT       = 6'd16,
        ST_TMPX_LOAD     = 6'd17,
        ST_TMPX_WAIT     = 6'd18,
        ST_X3_LOAD       = 6'd19,
        ST_X3_WAIT       = 6'd20,
        ST_VX_LOAD       = 6'd21,
        ST_VX_WAIT       = 6'd22,

        ST_BH_START      = 6'd23,
        ST_BH_WAIT       = 6'd24,

        ST_Y3_LOAD       = 6'd25,
        ST_Y3_WAIT       = 6'd26,

        ST_FINAL         = 6'd27,
        ST_DONE          = 6'd28
    } state_t;

    state_t state;

    logic [255:0] P_r;
    logic [255:0] X1_r, Y1_r, Z1_r;
    logic [255:0] X2_r, Y2_r, Z2_r;

    logic [255:0] Z1Z1_r, Z2Z2_r, Z1Z2_r;
    logic [255:0] U1_r, U2_r, Z1CUBE_r, Z2CUBE_r;
    logic [255:0] S1_r, S2_r;
    logic [255:0] H_r, R_r;
    logic [255:0] HH_r, RR_r, Z3_calc_r;
    logic [255:0] G_r, V_r;
    logic [255:0] twoV_r, tmpX_r, VX_r;
    logic [255:0] S1G_r, RVX_r;
    logic [255:0] X3_calc_r, Y3_calc_r;

    logic [255:0] X3_r, Y3_r, Z3_r;

    logic         stage_start;
    logic [4:0]   stage_op_count;
    logic         stage_busy;
    logic         stage_done;

    logic [255:0] A_vec [DEPTH];
    logic [255:0] B_vec [DEPTH];
    logic [255:0] S_vec [DEPTH];
    logic [255:0] R_vec [DEPTH];

    logic [255:0] add_A;
    logic [255:0] add_B;
    logic         add_SUB;
    logic [255:0] add_S;

    integer i;

    assign X3_out = X3_r;
    assign Y3_out = Y3_r;
    assign Z3_out = Z3_r;

    mult_wrap #(
        .DEPTH(DEPTH)
    ) U_STAGE_MUL (
        .clk         (clk),
        .rst_n       (rst_n),
        .start_stage (stage_start),
        .op_count    (stage_op_count),
        .N_mod       (P_r),
        .A_vec       (A_vec),
        .B_vec       (B_vec),
        .S_vec       (S_vec),
        .busy        (stage_busy),
        .done        (stage_done),
        .R_vec       (R_vec)
    );

    addsub_256 U_ADDSUB (
        .A   (add_A),
        .B   (add_B),
        .P   (P_r),
        .SUB (add_SUB),
        .S   (add_S)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            busy           <= 1'b0;
            done           <= 1'b0;
            stage_start    <= 1'b0;
            stage_op_count <= 5'd0;
            add_A          <= '0;
            add_B          <= '0;
            add_SUB        <= 1'b0;

            P_r            <= '0;
            X1_r           <= '0;
            Y1_r           <= '0;
            Z1_r           <= '0;
            X2_r           <= '0;
            Y2_r           <= '0;
            Z2_r           <= '0;

            Z1Z1_r         <= '0;
            Z2Z2_r         <= '0;
            Z1Z2_r         <= '0;
            U1_r           <= '0;
            U2_r           <= '0;
            Z1CUBE_r       <= '0;
            Z2CUBE_r       <= '0;
            S1_r           <= '0;
            S2_r           <= '0;
            H_r            <= '0;
            R_r            <= '0;
            HH_r           <= '0;
            RR_r           <= '0;
            Z3_calc_r      <= '0;
            G_r            <= '0;
            V_r            <= '0;
            twoV_r         <= '0;
            tmpX_r         <= '0;
            VX_r           <= '0;
            S1G_r          <= '0;
            RVX_r          <= '0;
            X3_calc_r      <= '0;
            Y3_calc_r      <= '0;

            X3_r           <= '0;
            Y3_r           <= '0;
            Z3_r           <= '0;

            for (i = 0; i < DEPTH; i = i + 1) begin
                A_vec[i] <= '0;
                B_vec[i] <= '0;
                S_vec[i] <= '0;
            end
        end else begin
            done        <= 1'b0;
            stage_start <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy  <= 1'b1;
                        P_r   <= P_mod;
                        X1_r  <= X1_in;
                        Y1_r  <= Y1_in;
                        Z1_r  <= Z1_in;
                        X2_r  <= X2_in;
                        Y2_r  <= Y2_in;
                        Z2_r  <= Z2_in;
                        state <= ST_BA_START;
                    end
                end

                ST_BA_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd3;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= Z1_r; B_vec[0] <= Z1_r;
                    A_vec[1] <= Z2_r; B_vec[1] <= Z2_r;
                    A_vec[2] <= Z1_r; B_vec[2] <= Z2_r;
                    state    <= ST_BA_WAIT;
                end

                ST_BA_WAIT: begin
                    if (stage_done) begin
                        Z1Z1_r <= R_vec[0];
                        Z2Z2_r <= R_vec[1];
                        Z1Z2_r <= R_vec[2];
                        state  <= ST_BB_START;
                    end
                end

                ST_BB_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd4;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= X1_r; B_vec[0] <= Z2Z2_r;
                    A_vec[1] <= X2_r; B_vec[1] <= Z1Z1_r;
                    A_vec[2] <= Z1_r; B_vec[2] <= Z1Z1_r;
                    A_vec[3] <= Z2_r; B_vec[3] <= Z2Z2_r;
                    state    <= ST_BB_WAIT;
                end

                ST_BB_WAIT: begin
                    if (stage_done) begin
                        U1_r     <= R_vec[0];
                        U2_r     <= R_vec[1];
                        Z1CUBE_r <= R_vec[2];
                        Z2CUBE_r <= R_vec[3];
                        state    <= ST_BC_START;
                    end
                end

                ST_BC_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd2;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= Y1_r; B_vec[0] <= Z2CUBE_r;
                    A_vec[1] <= Y2_r; B_vec[1] <= Z1CUBE_r;
                    state    <= ST_BC_WAIT;
                end

                ST_BC_WAIT: begin
                    if (stage_done) begin
                        S1_r  <= R_vec[0];
                        S2_r  <= R_vec[1];
                        state <= ST_H_LOAD;
                    end
                end

                ST_H_LOAD: begin
                    add_A   <= U1_r;
                    add_B   <= U2_r;
                    add_SUB <= 1'b1;
                    state   <= ST_H_WAIT;
                end

                ST_H_WAIT: begin
                    H_r   <= add_S;
                    state <= ST_R_LOAD;
                end

                ST_R_LOAD: begin
                    add_A   <= S1_r;
                    add_B   <= S2_r;
                    add_SUB <= 1'b1;
                    state   <= ST_R_WAIT;
                end

                ST_R_WAIT: begin
                    R_r   <= add_S;
                    state <= ST_BE_START;
                end

                ST_BE_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd3;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= H_r;    B_vec[0] <= H_r;
                    A_vec[1] <= R_r;    B_vec[1] <= R_r;
                    A_vec[2] <= Z1Z2_r; B_vec[2] <= H_r;
                    state    <= ST_BE_WAIT;
                end

                ST_BE_WAIT: begin
                    if (stage_done) begin
                        HH_r      <= R_vec[0];
                        RR_r      <= R_vec[1];
                        Z3_calc_r <= R_vec[2];
                        state     <= ST_BF_START;
                    end
                end

                ST_BF_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd2;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= H_r;  B_vec[0] <= HH_r;
                    A_vec[1] <= U1_r; B_vec[1] <= HH_r;
                    state    <= ST_BF_WAIT;
                end

                ST_BF_WAIT: begin
                    if (stage_done) begin
                        G_r   <= R_vec[0];
                        V_r   <= R_vec[1];
                        state <= ST_2V_LOAD;
                    end
                end

                ST_2V_LOAD: begin
                    add_A   <= V_r;
                    add_B   <= V_r;
                    add_SUB <= 1'b0;
                    state   <= ST_2V_WAIT;
                end

                ST_2V_WAIT: begin
                    twoV_r <= add_S;
                    state  <= ST_TMPX_LOAD;
                end

                ST_TMPX_LOAD: begin
                    add_A   <= RR_r;
                    add_B   <= G_r;
                    add_SUB <= 1'b0;
                    state   <= ST_TMPX_WAIT;
                end

                ST_TMPX_WAIT: begin
                    tmpX_r <= add_S;
                    state  <= ST_X3_LOAD;
                end

                ST_X3_LOAD: begin
                    add_A   <= tmpX_r;
                    add_B   <= twoV_r;
                    add_SUB <= 1'b1;
                    state   <= ST_X3_WAIT;
                end

                ST_X3_WAIT: begin
                    X3_calc_r <= add_S;
                    state     <= ST_VX_LOAD;
                end

                ST_VX_LOAD: begin
                    add_A   <= V_r;
                    add_B   <= X3_calc_r;
                    add_SUB <= 1'b1;
                    state   <= ST_VX_WAIT;
                end

                ST_VX_WAIT: begin
                    VX_r  <= add_S;
                    state <= ST_BH_START;
                end

                ST_BH_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd2;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= S1_r; B_vec[0] <= G_r;
                    A_vec[1] <= R_r;  B_vec[1] <= VX_r;
                    state    <= ST_BH_WAIT;
                end

                ST_BH_WAIT: begin
                    if (stage_done) begin
                        S1G_r <= R_vec[0];
                        RVX_r <= R_vec[1];
                        state <= ST_Y3_LOAD;
                    end
                end

                ST_Y3_LOAD: begin
                    add_A   <= RVX_r;
                    add_B   <= S1G_r;
                    add_SUB <= 1'b1;
                    state   <= ST_Y3_WAIT;
                end

                ST_Y3_WAIT: begin
                    Y3_calc_r <= add_S;
                    state     <= ST_FINAL;
                end

                ST_FINAL: begin
                    if ((Z1_r == 256'd0) && (Z2_r == 256'd0)) begin
                        X3_r <= 256'd0;
                        Y3_r <= 256'd0;
                        Z3_r <= 256'd0;
                    end else if (Z1_r == 256'd0) begin
                        X3_r <= X2_r;
                        Y3_r <= Y2_r;
                        Z3_r <= Z2_r;
                    end else if (Z2_r == 256'd0) begin
                        X3_r <= X1_r;
                        Y3_r <= Y1_r;
                        Z3_r <= Z1_r;
                    end else if ((H_r == 256'd0) && (R_r != 256'd0)) begin
                        X3_r <= 256'd0;
                        Y3_r <= 256'd0;
                        Z3_r <= 256'd0;
                    end else if ((H_r == 256'd0) && (R_r == 256'd0)) begin
                        // ladder  R0=P, R1=2P thi case nay không xay ra
                        // đe an toan thi van ep ra O
                        X3_r <= 256'd0;
                        Y3_r <= 256'd0;
                        Z3_r <= 256'd0;
                    end else begin
                        X3_r <= X3_calc_r;
                        Y3_r <= Y3_calc_r;
                        Z3_r <= Z3_calc_r;
                    end
                    state <= ST_DONE;
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