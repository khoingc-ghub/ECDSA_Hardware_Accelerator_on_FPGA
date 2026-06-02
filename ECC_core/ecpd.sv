`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 10:58:59 PM
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
    parameter int DEPTH = 4
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,

    input  logic [255:0] P_mod,
    input  logic [255:0] IP_mod,
    input  logic [51:0]  N0_prime_52,
    input  logic [255:0] a_curve,
    input  logic         a_is_zero,

    input  logic [255:0] X1_in,
    input  logic [255:0] Y1_in,
    input  logic [255:0] Z1_in,

    output logic         busy,
    output logic         done,

    output logic [255:0] X3_out,
    output logic [255:0] Y3_out,
    output logic [255:0] Z3_out
);

    typedef enum logic [4:0] {
        ST_IDLE          = 5'd0,
    
        ST_BA_START      = 5'd1,
        ST_BA_WAIT       = 5'd2,
    
        ST_BB_START      = 5'd3,
        ST_BB_WAIT       = 5'd4,
    
        ST_S2XYY_LOAD    = 5'd5,
        ST_S2XYY_WAIT    = 5'd6,
    
        ST_S4XYY_LOAD    = 5'd7,
        ST_S4XYY_WAIT    = 5'd8,
    
        ST_BC_START      = 5'd9,
        ST_BC_WAIT       = 5'd10,
    
        ST_M_ADD_LOAD    = 5'd11,
        ST_M_ADD_WAIT    = 5'd12,
    
        ST_BD_START      = 5'd13,
        ST_BD_WAIT       = 5'd14,
    
        ST_2S_LOAD       = 5'd15,
        ST_2S_WAIT       = 5'd16,
    
        ST_X3_LOAD       = 5'd17,
        ST_X3_WAIT       = 5'd18,
    
        ST_SX3_LOAD      = 5'd19,
        ST_SX3_WAIT      = 5'd20,
    
        ST_BE_START      = 5'd21,
        ST_BE_WAIT       = 5'd22,
    
        ST_Y3_LOAD       = 5'd23,
        ST_Y3_WAIT       = 5'd24,
    
        ST_FINAL         = 5'd25,
        ST_DONE          = 5'd26
    } state_t;

    state_t state;
    
    typedef enum logic [2:0] {
        MUL_NONE = 3'd0,
        MUL_BA   = 3'd1,
        MUL_BB   = 3'd2,
        MUL_BC   = 3'd3,
        MUL_BD   = 3'd4,
        MUL_BE   = 3'd5
    } mul_phase_t;

    typedef enum logic [2:0] {
        ADD_NONE = 3'd0,
        ADD_D0   = 3'd1,
        ADD_D1   = 3'd2,
        ADD_M    = 3'd3,
        ADD_D2   = 3'd4,
        ADD_X3   = 3'd5,
        ADD_SX3  = 3'd6,
        ADD_Y3   = 3'd7
    } add_phase_t;

    mul_phase_t mul_phase_r;
    add_phase_t add_phase_r;

    logic [255:0] P_r, IP_r, a_r;
    logic [255:0] X1_r, Y1_r, Z1_r;
    logic [51:0]  N0_prime_52_r;
    logic         a_is_zero_r;

    logic [255:0] XX_r, YY_r, ZZ_r, YZ_r;
    logic [255:0] YYYY_r, ZZZZ_r, XYY_r;
    logic [255:0] S_r, aZ4_r, M_r, M2_r;
    logic [255:0] SX3_r, eightYYYY_r, MSX3_r;

    logic [255:0] twoXYY_r, twoXX_r, threeXX_r;
    logic [255:0] twoS_r, twoYYYY_r, fourYYYY_r;

    logic [255:0] X3_calc_r, Y3_calc_r, Z3_calc_r;
    logic [255:0] X3_r, Y3_r, Z3_r;

    logic [255:0] add_A_c;
    logic [255:0] add_B_c;
    logic         add_SUB_c;
    logic         add_start_c;

    logic [255:0] add_S;
    logic         add_done;

    logic [2:0]   add_issue_idx;
    logic [2:0]   add_recv_cnt;
    logic [2:0]   add_tag0, add_tag1, add_tag2, add_tag3;

    // ====
    // Direct mult_top interface
    // Bỏ mult_wrap, bỏ A_vec/B_vec/S_vec/R_vec.
    // ====
    logic         mult_start;
    logic [255:0] mult_A_in;
    logic [255:0] mult_B_in;
    logic [255:0] mult_N_in;

    logic         mult_busy;
    logic [255:0] mult_R;
    logic         mult_R_valid;
    logic [1:0]   mult_R_idx;

    logic [1:0]   mult_load_idx;

    // Tránh start batch mới đúng lúc mult_top còn batch_done nội bộ
    logic         mult_can_issue;
    assign mult_can_issue = (mult_load_idx != 2'd0) || !mult_busy;
    
    integer i;

    assign X3_out = X3_r;
    assign Y3_out = Y3_r;
    assign Z3_out = Z3_r;

    mult_top #(
        .DEPTH(DEPTH)
    ) U_STAGE_MUL (
        .clk            (clk),
        .rst_n          (rst_n),
    
        .start          (mult_start),
        .A_in           (mult_A_in),
        .B_in           (mult_B_in),
        .N_in           (mult_N_in),
        .IP_mod         (IP_r),
        .N0_prime_52    (N0_prime_52_r),

        .busy           (mult_busy),

        .result_o       (mult_R),
        .result_valid_o (mult_R_valid),
        .result_idx_o   (mult_R_idx)
    );

    addsub_256 U_ADDSUB (
        .clk   (clk),
        .rst_n (rst_n),
        .start (add_start_c),
        .A     (add_A_c),
        .B     (add_B_c),
        .P     (P_r),
        .IP    (IP_r),
        .SUB   (add_SUB_c),
        .S     (add_S),
        .done  (add_done)
    );

    always_comb begin
        mult_start = 1'b0;
        mult_A_in  = 256'd0;
        mult_B_in  = 256'd0;
        mult_N_in  = P_r;

        case (state)
        // BA:
        // 0: XX = X1 * X1
        // 1: YY = Y1 * Y1
        // 2: ZZ = Z1 * Z1
        // 3: YZ = Y1 * Z1
            ST_BA_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = X1_r;
                            mult_B_in = X1_r;
                        end

                        2'd1: begin
                            mult_A_in = Y1_r;
                            mult_B_in = Y1_r;
                        end 

                        2'd2: begin
                            mult_A_in = Z1_r;
                            mult_B_in = Z1_r;
                        end

                        2'd3: begin
                            mult_A_in = Y1_r;
                            mult_B_in = Z1_r;
                        end
                    endcase
                end
            end

        // BB:
        // 0: YYYY = YY * YY
        // 1: ZZZZ = ZZ * ZZ
        // 2: XYY  = X1 * YY
        // 3: dummy
            ST_BB_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = YY_r;
                            mult_B_in = YY_r;
                        end

                        2'd1: begin
                            mult_A_in = ZZ_r;
                            mult_B_in = ZZ_r;
                        end

                        2'd2: begin
                            mult_A_in = X1_r;
                            mult_B_in = YY_r;
                        end

                        default: begin
                            mult_A_in = 256'd0;
                            mult_B_in = 256'd0;
                        end
                    endcase
                end
            end

        // BC:
        // 0: aZ4 = a * ZZZZ
        // 1..3: dummy
            ST_BC_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    if (mult_load_idx == 2'd0) begin
                        mult_A_in = a_r;
                        mult_B_in = ZZZZ_r;
                    end
                end
            end

        // BD:
        // 0: M2 = M * M
        // 1..3: dummy
            ST_BD_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    if (mult_load_idx == 2'd0) begin
                        mult_A_in = M_r;
                        mult_B_in = M_r;
                    end
                end
            end

        // BE:
        // 0: MSX3 = M * SX3
        // 1..3: dummy
            ST_BE_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    if (mult_load_idx == 2'd0) begin
                        mult_A_in = M_r;
                        mult_B_in = SX3_r;
                    end
                end
            end

            default: begin
                mult_start = 1'b0;
                mult_A_in  = 256'd0;
                mult_B_in  = 256'd0;
                mult_N_in  = P_r;
            end
        endcase
    end
    
    always_comb begin
        add_start_c = 1'b0;
        add_A_c     = 256'd0;
        add_B_c     = 256'd0;
        add_SUB_c   = 1'b0;

        case (state)
            // Batch D0:
            // op0: twoXYY   = XYY + XYY
            // op1: twoYYYY  = YYYY + YYYY
            // op2: twoXX    = XX + XX
            // op3: Z3_calc  = YZ + YZ
            ST_S2XYY_WAIT: begin
                if (add_issue_idx < 3'd4) begin
                    add_start_c = 1'b1;
    
                    case (add_issue_idx)
                        3'd0: begin
                            add_A_c   = XYY_r;
                            add_B_c   = XYY_r;
                            add_SUB_c = 1'b0;
                        end

                        3'd1: begin
                            add_A_c   = YYYY_r;
                            add_B_c   = YYYY_r;
                            add_SUB_c = 1'b0;
                        end

                        3'd2: begin
                            add_A_c   = XX_r;
                            add_B_c   = XX_r;
                            add_SUB_c = 1'b0;
                        end

                        3'd3: begin
                            add_A_c   = YZ_r;
                            add_B_c   = YZ_r;
                            add_SUB_c = 1'b0;
                        end
                    endcase
                end
            end

            // Batch D1:
            // op0: S         = twoXYY + twoXYY
            // op1: fourYYYY  = twoYYYY + twoYYYY
            // op2: threeXX   = twoXX + XX
            ST_S4XYY_WAIT: begin
                if (add_issue_idx < 3'd3) begin
                    add_start_c = 1'b1;

                    case (add_issue_idx)
                        3'd0: begin
                            add_A_c   = twoXYY_r;
                            add_B_c   = twoXYY_r;
                            add_SUB_c = 1'b0;
                        end

                        3'd1: begin
                            add_A_c   = twoYYYY_r;
                            add_B_c   = twoYYYY_r;
                            add_SUB_c = 1'b0;
                        end

                        3'd2: begin
                            add_A_c   = twoXX_r;
                            add_B_c   = XX_r;
                            add_SUB_c = 1'b0;
                        end
                    endcase
                end
            end

            // M = threeXX + aZ4
            ST_M_ADD_WAIT: begin
                if (add_issue_idx < 3'd1) begin
                    add_start_c = 1'b1;
                    add_A_c     = threeXX_r;
                    add_B_c     = aZ4_r;
                    add_SUB_c   = 1'b0;
                end
            end

            // Batch D2:
            // op0: twoS      = S + S
            // op1: eightYYYY = fourYYYY + fourYYYY
            ST_2S_WAIT: begin
                if (add_issue_idx < 3'd2) begin
                    add_start_c = 1'b1;

                    case (add_issue_idx)
                        3'd0: begin
                            add_A_c   = S_r;
                            add_B_c   = S_r;
                            add_SUB_c = 1'b0;
                        end

                        3'd1: begin
                            add_A_c   = fourYYYY_r;
                            add_B_c   = fourYYYY_r;
                            add_SUB_c = 1'b0;
                        end
                    endcase
                end
            end

            // X3 = M2 - twoS
            ST_X3_WAIT: begin
                if (add_issue_idx < 3'd1) begin
                    add_start_c = 1'b1;
                    add_A_c     = M2_r;
                    add_B_c     = twoS_r;
                    add_SUB_c   = 1'b1;
                end
            end

            // SX3 = S - X3
            ST_SX3_WAIT: begin
                if (add_issue_idx < 3'd1) begin
                    add_start_c = 1'b1;
                    add_A_c     = S_r;
                    add_B_c     = X3_calc_r;
                    add_SUB_c   = 1'b1;
                end
            end

            // Y3 = MSX3 - eightYYYY
            ST_Y3_WAIT: begin
                if (add_issue_idx < 3'd1) begin
                    add_start_c = 1'b1;
                    add_A_c     = MSX3_r;
                    add_B_c     = eightYYYY_r;
                    add_SUB_c   = 1'b1;
                end
            end

            default: begin
                add_start_c = 1'b0;
                add_A_c     = 256'd0;
                add_B_c     = 256'd0;
                add_SUB_c   = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            busy           <= 1'b0;
            done           <= 1'b0;
            add_issue_idx  <= '0;
            add_recv_cnt   <= '0;
            add_tag0       <= '0;
            add_tag1       <= '0;
            add_tag2       <= '0;
            add_tag3       <= '0;
            mult_load_idx  <= 2'd0;
            mul_phase_r <= MUL_NONE;
            add_phase_r <= ADD_NONE;

            P_r            <= '0;
            IP_r           <= '0;
            a_r            <= '0;
            a_is_zero_r    <= 1'b0;
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
        end else begin
            done        <= 1'b0;

            if (add_start_c) begin
                add_tag0 <= add_issue_idx;
            end

            add_tag1 <= add_tag0;
            add_tag2 <= add_tag1;
            add_tag3 <= add_tag2;   

if (mult_R_valid) begin
    case (mul_phase_r)
        MUL_BA: begin
            case (mult_R_idx)
                2'd0: XX_r <= mult_R;
                2'd1: YY_r <= mult_R;
                2'd2: ZZ_r <= mult_R;
                2'd3: YZ_r <= mult_R;
            endcase
        end

        MUL_BB: begin
            case (mult_R_idx)
                2'd0: YYYY_r <= mult_R;
                2'd1: ZZZZ_r <= mult_R;
                2'd2: XYY_r  <= mult_R;
                default: ;
            endcase
        end

        MUL_BC: begin
            if (mult_R_idx == 2'd0)
                aZ4_r <= mult_R;
        end

        MUL_BD: begin
            if (mult_R_idx == 2'd0)
                M2_r <= mult_R;
        end

        MUL_BE: begin
            if (mult_R_idx == 2'd0)
                MSX3_r <= mult_R;
        end

        default: ;
    endcase

    if (mult_R_idx == 2'd3)
        mul_phase_r <= MUL_NONE;
end

if (add_done) begin
    case (add_phase_r)
        ADD_D0: begin
            case (add_tag2)
                3'd0: twoXYY_r  <= add_S;
                3'd1: twoYYYY_r <= add_S;
                3'd2: twoXX_r   <= add_S;
                3'd3: Z3_calc_r <= add_S;
                default: ;
            endcase
        end

        ADD_D1: begin
            case (add_tag2)
                3'd0: S_r <= add_S;

                3'd1: fourYYYY_r <= add_S;

                3'd2: begin
                    threeXX_r <= add_S;

                    // k1: a = 0, M = threeXX
                    if (a_is_zero_r)
                        M_r <= add_S;
                end

                default: ;
            endcase
        end

        ADD_M: begin
            M_r <= add_S;
        end

        ADD_D2: begin
            case (add_tag2)
                3'd0: twoS_r      <= add_S;
                3'd1: eightYYYY_r <= add_S;
                default: ;
            endcase
        end

        ADD_X3: begin
            X3_calc_r <= add_S;
        end

        ADD_SX3: begin
            SX3_r <= add_S;
        end

        ADD_Y3: begin
            Y3_calc_r <= add_S;
        end

        default: ;
    endcase
end

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy  <= 1'b1;
                        P_r   <= P_mod;
                        IP_r  <= IP_mod;
                        N0_prime_52_r <= N0_prime_52;
                        a_r   <= a_curve;
                        a_is_zero_r   <= a_is_zero;
                        X1_r  <= X1_in;
                        Y1_r  <= Y1_in;
                        Z1_r  <= Z1_in;
                        mult_load_idx <= 2'd0;
                        state <= ST_BA_START;
                    end
                end

                ST_BA_START: begin
                    if (mult_can_issue) begin
                        if (mult_load_idx == 2'd0)
                            mul_phase_r <= MUL_BA;
                            
                        if (mult_load_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BA_WAIT;
                        end
                        else begin
                            mult_load_idx <= mult_load_idx + 1'b1;
                        end
                    end
                end

                ST_BA_WAIT: begin
                    if (mult_R_valid) begin
                        if (mult_R_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BB_START;
                        end
                    end
                end
                ST_BB_START: begin
                    if (mult_can_issue) begin
                        if (mult_load_idx == 2'd0)
                            mul_phase_r <= MUL_BB;
                            
                        if (mult_load_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BB_WAIT;
                        end
                        else begin
                            mult_load_idx <= mult_load_idx + 1'b1;
                        end
                    end
                end

                ST_BB_WAIT: begin
                    if (mult_R_valid) begin
                        if (mult_R_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_S2XYY_LOAD;
                        end
                    end
                end

                ST_S2XYY_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_D0;
                    state         <= ST_S2XYY_WAIT;
                end

                ST_S2XYY_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        if (add_recv_cnt == 3'd3) begin
                            add_recv_cnt  <= 3'd0;
                            add_issue_idx <= 3'd0;
                            add_phase_r   <= ADD_NONE;
                            state         <= ST_S4XYY_LOAD;
                        end
                        else begin
                            add_recv_cnt <= add_recv_cnt + 1'b1;
                        end
                    end
                end

                ST_S4XYY_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_D1;
                    state         <= ST_S4XYY_WAIT;
                end

                ST_S4XYY_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        if (add_recv_cnt == 3'd2) begin
                            add_recv_cnt  <= 3'd0;
                            add_issue_idx <= 3'd0;
                            add_phase_r   <= ADD_NONE;
                            mult_load_idx <= 2'd0;
                            
                            if (a_is_zero_r) begin
                                state <= ST_BD_START;
                            end
                            else begin
                                state <= ST_BC_START;
                            end
                        end
                        else begin
                            add_recv_cnt <= add_recv_cnt + 1'b1;
                        end
                    end
                end

                ST_BC_START: begin
                    if (mult_can_issue) begin
                        if (mult_load_idx == 2'd0)
                            mul_phase_r <= MUL_BC;
                            
                        if (mult_load_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BC_WAIT;
                        end
                        else begin
                            mult_load_idx <= mult_load_idx + 1'b1;
                        end
                    end
                end

                ST_BC_WAIT: begin
                    if (mult_R_valid) begin
                        if (mult_R_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_M_ADD_LOAD;
                        end
                    end
                end

                ST_M_ADD_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_M;
                    state         <= ST_M_ADD_WAIT;
                end

                ST_M_ADD_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        add_issue_idx <= 3'd0;
                        add_recv_cnt  <= 3'd0;
                        add_phase_r   <= ADD_NONE;
                        mult_load_idx <= 2'd0;
                        state         <= ST_BD_START;
                    end
                end

                ST_BD_START: begin
                    if (mult_can_issue) begin
                        if (mult_load_idx == 2'd0)
                            mul_phase_r <= MUL_BD;
                            
                        if (mult_load_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BD_WAIT;
                        end
                        else begin
                            mult_load_idx <= mult_load_idx + 1'b1;
                        end
                    end
                end

                ST_BD_WAIT: begin
                    if (mult_R_valid) begin
                        if (mult_R_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_2S_LOAD;
                        end
                    end
                end

                ST_2S_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_D2;
                    state         <= ST_2S_WAIT;
                end

                ST_2S_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        if (add_recv_cnt == 3'd1) begin
                            add_recv_cnt  <= 3'd0;
                            add_issue_idx <= 3'd0;
                            add_phase_r   <= ADD_NONE;
                            state         <= ST_X3_LOAD;
                        end
                        else begin
                            add_recv_cnt <= add_recv_cnt + 1'b1;
                        end
                    end
                end

                ST_X3_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_X3;
                    state         <= ST_X3_WAIT;
                end

                ST_X3_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        add_issue_idx <= 3'd0;
                        add_recv_cnt  <= 3'd0;
                        add_phase_r   <= ADD_NONE;
                        state         <= ST_SX3_LOAD;
                    end
                end

                ST_SX3_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_SX3;
                    state         <= ST_SX3_WAIT;
                end

                ST_SX3_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        add_issue_idx <= 3'd0;
                        add_recv_cnt  <= 3'd0;
                        add_phase_r   <= ADD_NONE;
                        mult_load_idx <= 2'd0;
                        state         <= ST_BE_START;
                    end
                end

                ST_BE_START: begin
                    if (mult_can_issue) begin
                        if (mult_load_idx == 2'd0)
                            mul_phase_r <= MUL_BE;
                            
                        if (mult_load_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BE_WAIT;
                        end
                        else begin
                            mult_load_idx <= mult_load_idx + 1'b1;
                        end
                    end
                end

                ST_BE_WAIT: begin
                    if (mult_R_valid) begin
                        if (mult_R_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_Y3_LOAD;
                        end
                    end
                end

                ST_Y3_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_Y3;
                    state         <= ST_Y3_WAIT;
                end

                ST_Y3_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        add_issue_idx <= 3'd0;
                        add_recv_cnt  <= 3'd0;
                        add_phase_r   <= ADD_NONE;
                        state         <= ST_FINAL;
                    end
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
