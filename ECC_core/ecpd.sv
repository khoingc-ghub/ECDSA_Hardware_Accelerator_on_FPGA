`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/09/2026 05:42:39 PM
// Design Name: 
// Module Name: ecpd
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




module ecpd #(
    parameter int DEPTH = 16
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,

    input  logic [255:0] P_mod,
    input  logic [255:0] a_curve,

    input  logic [255:0] X1_in,
    input  logic [255:0] Y1_in,
    input  logic [255:0] Z1_in,

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

        ST_S2XYY_LOAD    = 6'd5,
        ST_S2XYY_WAIT    = 6'd6,
        ST_S4XYY_LOAD    = 6'd7,
        ST_S4XYY_WAIT    = 6'd8,
        ST_Z3_2YZ_LOAD   = 6'd9,
        ST_Z3_2YZ_WAIT   = 6'd10,

        ST_BC_START      = 6'd11,
        ST_BC_WAIT       = 6'd12,

        ST_2XX_LOAD      = 6'd13,
        ST_2XX_WAIT      = 6'd14,
        ST_3XX_LOAD      = 6'd15,
        ST_3XX_WAIT      = 6'd16,
        ST_M_ADD_LOAD    = 6'd17,
        ST_M_ADD_WAIT    = 6'd18,

        ST_BD_START      = 6'd19,
        ST_BD_WAIT       = 6'd20,

        ST_2S_LOAD       = 6'd21,
        ST_2S_WAIT       = 6'd22,
        ST_X3_LOAD       = 6'd23,
        ST_X3_WAIT       = 6'd24,
        ST_SX3_LOAD      = 6'd25,
        ST_SX3_WAIT      = 6'd26,

        ST_2YYYY_LOAD    = 6'd27,
        ST_2YYYY_WAIT    = 6'd28,
        ST_4YYYY_LOAD    = 6'd29,
        ST_4YYYY_WAIT    = 6'd30,
        ST_8YYYY_LOAD    = 6'd31,
        ST_8YYYY_WAIT    = 6'd32,

        ST_BE_START      = 6'd33,
        ST_BE_WAIT       = 6'd34,

        ST_Y3_LOAD       = 6'd35,
        ST_Y3_WAIT       = 6'd36,

        ST_FINAL         = 6'd37,
        ST_DONE          = 6'd38
    } state_t;

    state_t state;

    logic [255:0] P_r, a_r;
    logic [255:0] X1_r, Y1_r, Z1_r;

    logic [255:0] XX_r, YY_r, ZZ_r, YZ_r;
    logic [255:0] YYYY_r, ZZZZ_r, XYY_r;
    logic [255:0] S_r, aZ4_r, M_r, M2_r;
    logic [255:0] SX3_r, eightYYYY_r, MSX3_r;

    logic [255:0] twoXYY_r, twoXX_r, threeXX_r;
    logic [255:0] twoS_r, twoYYYY_r, fourYYYY_r;

    logic [255:0] X3_calc_r, Y3_calc_r, Z3_calc_r;
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
            a_r            <= '0;
            X1_r           <= '0;
            Y1_r           <= '0;
            Z1_r           <= '0;

            XX_r           <= '0;
            YY_r           <= '0;
            ZZ_r           <= '0;
            YZ_r           <= '0;
            YYYY_r         <= '0;
            ZZZZ_r         <= '0;
            XYY_r          <= '0;
            S_r            <= '0;
            aZ4_r          <= '0;
            M_r            <= '0;
            M2_r           <= '0;
            SX3_r          <= '0;
            eightYYYY_r    <= '0;
            MSX3_r         <= '0;
            twoXYY_r       <= '0;
            twoXX_r        <= '0;
            threeXX_r      <= '0;
            twoS_r         <= '0;
            twoYYYY_r      <= '0;
            fourYYYY_r     <= '0;

            X3_calc_r      <= '0;
            Y3_calc_r      <= '0;
            Z3_calc_r      <= '0;
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
                        a_r   <= a_curve;
                        X1_r  <= X1_in;
                        Y1_r  <= Y1_in;
                        Z1_r  <= Z1_in;
                        state <= ST_BA_START;
                    end
                end

                ST_BA_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd4;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= X1_r; B_vec[0] <= X1_r;
                    A_vec[1] <= Y1_r; B_vec[1] <= Y1_r;
                    A_vec[2] <= Z1_r; B_vec[2] <= Z1_r;
                    A_vec[3] <= Y1_r; B_vec[3] <= Z1_r;
                    state    <= ST_BA_WAIT;
                end

                ST_BA_WAIT: begin
                    if (stage_done) begin
                        XX_r  <= R_vec[0];
                        YY_r  <= R_vec[1];
                        ZZ_r  <= R_vec[2];
                        YZ_r  <= R_vec[3];
                        state <= ST_BB_START;
                    end
                end

                ST_BB_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd3;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= YY_r; B_vec[0] <= YY_r;
                    A_vec[1] <= ZZ_r; B_vec[1] <= ZZ_r;
                    A_vec[2] <= X1_r; B_vec[2] <= YY_r;
                    state    <= ST_BB_WAIT;
                end

                ST_BB_WAIT: begin
                    if (stage_done) begin
                        YYYY_r <= R_vec[0];
                        ZZZZ_r <= R_vec[1];
                        XYY_r  <= R_vec[2];
                        state  <= ST_S2XYY_LOAD;
                    end
                end

                ST_S2XYY_LOAD: begin
                    add_A   <= XYY_r;
                    add_B   <= XYY_r;
                    add_SUB <= 1'b0;
                    state   <= ST_S2XYY_WAIT;
                end

                ST_S2XYY_WAIT: begin
                    twoXYY_r <= add_S;
                    state    <= ST_S4XYY_LOAD;
                end

                ST_S4XYY_LOAD: begin
                    add_A   <= twoXYY_r;
                    add_B   <= twoXYY_r;
                    add_SUB <= 1'b0;
                    state   <= ST_S4XYY_WAIT;
                end

                ST_S4XYY_WAIT: begin
                    S_r   <= add_S;
                    state <= ST_Z3_2YZ_LOAD;
                end

                ST_Z3_2YZ_LOAD: begin
                    add_A   <= YZ_r;
                    add_B   <= YZ_r;
                    add_SUB <= 1'b0;
                    state   <= ST_Z3_2YZ_WAIT;
                end

                ST_Z3_2YZ_WAIT: begin
                    Z3_calc_r <= add_S;
                    state     <= ST_BC_START;
                end

                ST_BC_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd1;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= a_r;
                    B_vec[0] <= ZZZZ_r;
                    state    <= ST_BC_WAIT;
                end

                ST_BC_WAIT: begin
                    if (stage_done) begin
                        aZ4_r <= R_vec[0];
                        state <= ST_2XX_LOAD;
                    end
                end

                ST_2XX_LOAD: begin
                    add_A   <= XX_r;
                    add_B   <= XX_r;
                    add_SUB <= 1'b0;
                    state   <= ST_2XX_WAIT;
                end

                ST_2XX_WAIT: begin
                    twoXX_r <= add_S;
                    state   <= ST_3XX_LOAD;
                end

                ST_3XX_LOAD: begin
                    add_A   <= twoXX_r;
                    add_B   <= XX_r;
                    add_SUB <= 1'b0;
                    state   <= ST_3XX_WAIT;
                end

                ST_3XX_WAIT: begin
                    threeXX_r <= add_S;
                    state     <= ST_M_ADD_LOAD;
                end

                ST_M_ADD_LOAD: begin
                    add_A   <= threeXX_r;
                    add_B   <= aZ4_r;
                    add_SUB <= 1'b0;
                    state   <= ST_M_ADD_WAIT;
                end

                ST_M_ADD_WAIT: begin
                    M_r   <= add_S;
                    state <= ST_BD_START;
                end

                ST_BD_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd1;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= M_r;
                    B_vec[0] <= M_r;
                    state    <= ST_BD_WAIT;
                end

                ST_BD_WAIT: begin
                    if (stage_done) begin
                        M2_r  <= R_vec[0];
                        state <= ST_2S_LOAD;
                    end
                end

                ST_2S_LOAD: begin
                    add_A   <= S_r;
                    add_B   <= S_r;
                    add_SUB <= 1'b0;
                    state   <= ST_2S_WAIT;
                end

                ST_2S_WAIT: begin
                    twoS_r <= add_S;
                    state  <= ST_X3_LOAD;
                end

                ST_X3_LOAD: begin
                    add_A   <= M2_r;
                    add_B   <= twoS_r;
                    add_SUB <= 1'b1;
                    state   <= ST_X3_WAIT;
                end

                ST_X3_WAIT: begin
                    X3_calc_r <= add_S;
                    state     <= ST_SX3_LOAD;
                end

                ST_SX3_LOAD: begin
                    add_A   <= S_r;
                    add_B   <= X3_calc_r;
                    add_SUB <= 1'b1;
                    state   <= ST_SX3_WAIT;
                end

                ST_SX3_WAIT: begin
                    SX3_r <= add_S;
                    state <= ST_2YYYY_LOAD;
                end

                ST_2YYYY_LOAD: begin
                    add_A   <= YYYY_r;
                    add_B   <= YYYY_r;
                    add_SUB <= 1'b0;
                    state   <= ST_2YYYY_WAIT;
                end

                ST_2YYYY_WAIT: begin
                    twoYYYY_r <= add_S;
                    state     <= ST_4YYYY_LOAD;
                end

                ST_4YYYY_LOAD: begin
                    add_A   <= twoYYYY_r;
                    add_B   <= twoYYYY_r;
                    add_SUB <= 1'b0;
                    state   <= ST_4YYYY_WAIT;
                end

                ST_4YYYY_WAIT: begin
                    fourYYYY_r <= add_S;
                    state      <= ST_8YYYY_LOAD;
                end

                ST_8YYYY_LOAD: begin
                    add_A   <= fourYYYY_r;
                    add_B   <= fourYYYY_r;
                    add_SUB <= 1'b0;
                    state   <= ST_8YYYY_WAIT;
                end

                ST_8YYYY_WAIT: begin
                    eightYYYY_r <= add_S;
                    state       <= ST_BE_START;
                end

                ST_BE_START: begin
                    stage_start    <= 1'b1;
                    stage_op_count <= 5'd1;
                    for (i = 0; i < DEPTH; i = i + 1) begin
                        A_vec[i] <= '0;
                        B_vec[i] <= '0;
                        S_vec[i] <= '0;
                    end
                    A_vec[0] <= M_r;
                    B_vec[0] <= SX3_r;
                    state    <= ST_BE_WAIT;
                end

                ST_BE_WAIT: begin
                    if (stage_done) begin
                        MSX3_r <= R_vec[0];
                        state  <= ST_Y3_LOAD;
                    end
                end

                ST_Y3_LOAD: begin
                    add_A   <= MSX3_r;
                    add_B   <= eightYYYY_r;
                    add_SUB <= 1'b1;
                    state   <= ST_Y3_WAIT;
                end

                ST_Y3_WAIT: begin
                    Y3_calc_r <= add_S;
                    state     <= ST_FINAL;
                end

                ST_FINAL: begin
                    if ((Z1_r == 256'd0) || (Y1_r == 256'd0)) begin
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