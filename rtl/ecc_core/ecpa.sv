`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 10:58:44 PM
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


`timescale 1ns / 1ps

module ecpa #(
    parameter int DEPTH = 4
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,

    input  logic [255:0] P_mod,
    input  logic [255:0] IP_mod,
    input  logic [51:0]  N0_prime_52,

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

    typedef enum logic [4:0] {
        ST_IDLE          = 5'd0,

        ST_BA_START      = 5'd1,
        ST_BA_WAIT       = 5'd2,

        ST_BB_START      = 5'd3,
        ST_BB_WAIT       = 5'd4,

        ST_BC_START      = 5'd5,
        ST_BC_WAIT       = 5'd6,

        ST_H_LOAD        = 5'd7,
        ST_H_WAIT        = 5'd8,

        ST_BE_START      = 5'd9,
        ST_BE_WAIT       = 5'd10,

        ST_BF_START      = 5'd11,
        ST_BF_WAIT       = 5'd12,

        ST_2V_LOAD       = 5'd13,
        ST_2V_WAIT       = 5'd14,

        ST_X3_LOAD       = 5'd15,
        ST_X3_WAIT       = 5'd16,

        ST_VX_LOAD       = 5'd17,
        ST_VX_WAIT       = 5'd18,

        ST_BH_START      = 5'd19,
        ST_BH_WAIT       = 5'd20,

        ST_Y3_LOAD       = 5'd21,
        ST_Y3_WAIT       = 5'd22,

        ST_FINAL         = 5'd23,
        ST_DONE          = 5'd24
    } state_t;

    state_t state;

    typedef enum logic [2:0] {
        MUL_NONE = 3'd0,
        MUL_BA   = 3'd1,
        MUL_BB   = 3'd2,
        MUL_BC   = 3'd3,
        MUL_BE   = 3'd4,
        MUL_BF   = 3'd5,
        MUL_BH   = 3'd6
    } mul_phase_t;

    typedef enum logic [2:0] {
        ADD_NONE = 3'd0,
        ADD_HR   = 3'd1,
        ADD_XPRE = 3'd2,
        ADD_X3   = 3'd3,
        ADD_VX   = 3'd4,
        ADD_Y3   = 3'd5
    } add_phase_t;

    mul_phase_t mul_phase_r;
    add_phase_t add_phase_r;

    // =====================================================
    // Curve/input registers
    // =====================================================
    logic [255:0] P_r;
    logic [255:0] IP_r;
    logic [51:0]  N0_prime_52_r;

    logic [255:0] X1_r;
    logic [255:0] Y1_r;
    logic [255:0] Z1_r;

    logic [255:0] X2_r;
    logic [255:0] Y2_r;
    logic [255:0] Z2_r;

    // =====================================================
    // ECPA internal registers
    // =====================================================
    logic [255:0] Z1Z1_r;
    logic [255:0] Z2Z2_r;
    logic [255:0] Z1Z2_r;

    logic [255:0] U1_r;
    logic [255:0] U2_r;
    logic [255:0] Z1CUBE_r;
    logic [255:0] Z2CUBE_r;

    logic [255:0] S1_r;
    logic [255:0] S2_r;

    logic [255:0] H_r;
    logic [255:0] R_r;

    logic [255:0] HH_r;
    logic [255:0] RR_r;
    logic [255:0] Z3_calc_r;

    logic [255:0] G_r;
    logic [255:0] V_r;

    logic [255:0] twoV_r;
    logic [255:0] tmpX_r;
    logic [255:0] X3_calc_r;
    logic [255:0] VX_r;

    logic [255:0] S1G_r;
    logic [255:0] RVX_r;
    logic [255:0] Y3_calc_r;

    logic [255:0] X3_r;
    logic [255:0] Y3_r;
    logic [255:0] Z3_r;

    assign X3_out = X3_r;
    assign Y3_out = Y3_r;
    assign Z3_out = Z3_r;

    // =====================================================
    // Direct mult_top interface
    // Bỏ mult_wrap, bỏ A_vec/B_vec/R_vec.
    // =====================================================
    logic         mult_start;
    logic [255:0] mult_A_in;
    logic [255:0] mult_B_in;
    logic [255:0] mult_N_in;

    logic         mult_busy;
    logic [255:0] mult_R;
    logic         mult_R_valid;
    logic [1:0]   mult_R_idx;

    logic [1:0]   mult_load_idx;

    // Chỉ chặn slot 0 của batch mới khi mult_top còn busy.
    // Slot 1/2/3 của batch đang nạp thì vẫn phải đi liên tục.
    logic         mult_can_issue;
    assign mult_can_issue = (mult_load_idx != 2'd0) || !mult_busy;

    // =====================================================
    // Addsub pipeline interface
    // =====================================================
    logic [255:0] add_A_c;
    logic [255:0] add_B_c;
    logic         add_SUB_c;
    logic         add_start_c;

    logic [255:0] add_S;
    logic         add_done;

    logic [2:0]   add_issue_idx;
    logic [2:0]   add_recv_cnt;
    logic [2:0]   add_tag0, add_tag1, add_tag2, add_tag3;
    logic         add_v0, add_v1, add_v2, add_v3;

    // =====================================================
    // Direct mult_top instance
    // Dựa theo mult_top stream-output hiện tại.
    // =====================================================
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

    // =====================================================
    // Chọn input trực tiếp cho mult_top theo state + index
    // =====================================================
    always_comb begin
        mult_start = 1'b0;
        mult_A_in  = 256'd0;
        mult_B_in  = 256'd0;
        mult_N_in  = P_r;

        case (state)
            // -------------------------------------------------
            // BA:
            // 0: Z1Z1 = Z1 * Z1
            // 1: Z2Z2 = Z2 * Z2
            // 2: Z1Z2 = Z1 * Z2
            // 3: dummy
            // -------------------------------------------------
            ST_BA_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = Z1_r;
                            mult_B_in = Z1_r;
                        end

                        2'd1: begin
                            mult_A_in = Z2_r;
                            mult_B_in = Z2_r;
                        end

                        2'd2: begin
                            mult_A_in = Z1_r;
                            mult_B_in = Z2_r;
                        end

                        default: begin
                            mult_A_in = 256'd0;
                            mult_B_in = 256'd0;
                        end
                    endcase
                end
            end

            // -------------------------------------------------
            // BB:
            // 0: U1     = X1 * Z2Z2
            // 1: U2     = X2 * Z1Z1
            // 2: Z1CUBE = Z1 * Z1Z1
            // 3: Z2CUBE = Z2 * Z2Z2
            // -------------------------------------------------
            ST_BB_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = X1_r;
                            mult_B_in = Z2Z2_r;
                        end

                        2'd1: begin
                            mult_A_in = X2_r;
                            mult_B_in = Z1Z1_r;
                        end

                        2'd2: begin
                            mult_A_in = Z1_r;
                            mult_B_in = Z1Z1_r;
                        end

                        2'd3: begin
                            mult_A_in = Z2_r;
                            mult_B_in = Z2Z2_r;
                        end
                    endcase
                end
            end

            // -------------------------------------------------
            // BC:
            // 0: S1 = Y1 * Z2CUBE
            // 1: S2 = Y2 * Z1CUBE
            // 2,3: dummy
            // -------------------------------------------------
            ST_BC_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = Y1_r;
                            mult_B_in = Z2CUBE_r;
                        end

                        2'd1: begin
                            mult_A_in = Y2_r;
                            mult_B_in = Z1CUBE_r;
                        end

                        default: begin
                            mult_A_in = 256'd0;
                            mult_B_in = 256'd0;
                        end
                    endcase
                end
            end

            // -------------------------------------------------
            // BE:
            // 0: HH = H * H
            // 1: RR = R * R
            // 2: Z3 = Z1Z2 * H
            // 3: dummy
            // -------------------------------------------------
            ST_BE_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = H_r;
                            mult_B_in = H_r;
                        end

                        2'd1: begin
                            mult_A_in = R_r;
                            mult_B_in = R_r;
                        end

                        2'd2: begin
                            mult_A_in = Z1Z2_r;
                            mult_B_in = H_r;
                        end

                        default: begin
                            mult_A_in = 256'd0;
                            mult_B_in = 256'd0;
                        end
                    endcase
                end
            end

            // -------------------------------------------------
            // BF:
            // 0: G = H * HH
            // 1: V = U1 * HH
            // 2,3: dummy
            // -------------------------------------------------
            ST_BF_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = H_r;
                            mult_B_in = HH_r;
                        end

                        2'd1: begin
                            mult_A_in = U1_r;
                            mult_B_in = HH_r;
                        end

                        default: begin
                            mult_A_in = 256'd0;
                            mult_B_in = 256'd0;
                        end
                    endcase
                end
            end

            // -------------------------------------------------
            // BH:
            // 0: S1G = S1 * G
            // 1: RVX = R * VX
            // 2,3: dummy
            // -------------------------------------------------
            ST_BH_START: begin
                if (mult_can_issue) begin
                    mult_start = 1'b1;

                    case (mult_load_idx)
                        2'd0: begin
                            mult_A_in = S1_r;
                            mult_B_in = G_r;
                        end

                        2'd1: begin
                            mult_A_in = R_r;
                            mult_B_in = VX_r;
                        end

                        default: begin
                            mult_A_in = 256'd0;
                            mult_B_in = 256'd0;
                        end
                    endcase
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
            // Batch 0:
            // op0: H = U1 - U2
            // op1: R = S1 - S2
            ST_H_WAIT: begin
                if (add_issue_idx < 3'd2) begin
                    add_start_c = 1'b1;

                    case (add_issue_idx)
                        3'd0: begin
                            add_A_c   = U1_r;
                            add_B_c   = U2_r;
                            add_SUB_c = 1'b1;
                        end

                        3'd1: begin
                            add_A_c   = S1_r;
                            add_B_c   = S2_r;
                            add_SUB_c = 1'b1;
                        end
                    endcase
                end
            end

            // Batch 1:
            // op0: twoV = V + V
            // op1: tmpX = RR + G
            ST_2V_WAIT: begin
                if (add_issue_idx < 3'd2) begin
                    add_start_c = 1'b1;

                    case (add_issue_idx)
                        3'd0: begin
                            add_A_c   = V_r;
                            add_B_c   = V_r;
                            add_SUB_c = 1'b0;
                        end

                        3'd1: begin
                            add_A_c   = RR_r;
                            add_B_c   = G_r;
                            add_SUB_c = 1'b0;
                        end
                    endcase
                end
            end

            // Single op:
            // X3 = tmpX - twoV
            ST_X3_WAIT: begin
                if (add_issue_idx < 3'd1) begin
                    add_start_c = 1'b1;
                    add_A_c     = tmpX_r;
                    add_B_c     = twoV_r;
                    add_SUB_c   = 1'b1;
                end
            end

            // VX = V - X3
            ST_VX_WAIT: begin
                if (add_issue_idx < 3'd1) begin
                    add_start_c = 1'b1;
                    add_A_c     = V_r;
                    add_B_c     = X3_calc_r;
                    add_SUB_c   = 1'b1;
                end
            end

            // Y3 = RVX - S1G
            ST_Y3_WAIT: begin
                if (add_issue_idx < 3'd1) begin
                    add_start_c = 1'b1;
                    add_A_c     = RVX_r;
                    add_B_c     = S1G_r;
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
    
    // =====================================================
    // Main FSM
    // =====================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            busy           <= 1'b0;
            done           <= 1'b0;
            
            mul_phase_r <= MUL_NONE;
            add_phase_r <= ADD_NONE;

            P_r            <= '0;
            IP_r           <= '0;
            N0_prime_52_r  <= '0;

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
            X3_calc_r      <= '0;
            VX_r           <= '0;

            S1G_r          <= '0;
            RVX_r          <= '0;
            Y3_calc_r      <= '0;

            X3_r           <= '0;
            Y3_r           <= '0;
            Z3_r           <= '0;

            add_issue_idx  <= '0;
            add_recv_cnt   <= '0;
            add_tag0       <= '0;
            add_tag1       <= '0;
            add_tag2       <= '0;
            add_tag3       <= '0;
            add_v0 <= 1'b0;
            add_v1 <= 1'b0;
            add_v2 <= 1'b0;
            add_v3 <= 1'b0;

            mult_load_idx  <= 2'd0;
        end
        else begin
            done      <= 1'b0;
            add_v0    <= add_start_c;
            add_v1    <= add_v0;
            add_v2    <= add_v1;
            add_v3    <= add_v2;

            if (add_start_c) begin
                add_tag0 <= add_issue_idx;
            end

            add_tag1 <= add_tag0;
            add_tag2 <= add_tag1;
            add_tag3 <= add_tag2;
            
            // =====================================================
// MULT result commit
// Không dùng state để ghi reg 256-bit nữa
// =====================================================
if (mult_R_valid) begin
    case (mul_phase_r)
        MUL_BA: begin
            case (mult_R_idx)
                2'd0: Z1Z1_r <= mult_R;
                2'd1: Z2Z2_r <= mult_R;
                2'd2: Z1Z2_r <= mult_R;
                default: ;
            endcase
        end

        MUL_BB: begin
            case (mult_R_idx)
                2'd0: U1_r     <= mult_R;
                2'd1: U2_r     <= mult_R;
                2'd2: Z1CUBE_r <= mult_R;
                2'd3: Z2CUBE_r <= mult_R;
            endcase
        end

        MUL_BC: begin
            case (mult_R_idx)
                2'd0: S1_r <= mult_R;
                2'd1: S2_r <= mult_R;
                default: ;
            endcase
        end

        MUL_BE: begin
            case (mult_R_idx)
                2'd0: HH_r      <= mult_R;
                2'd1: RR_r      <= mult_R;
                2'd2: Z3_calc_r <= mult_R;
                default: ;
            endcase
        end

        MUL_BF: begin
            case (mult_R_idx)
                2'd0: G_r <= mult_R;
                2'd1: V_r <= mult_R;
                default: ;
            endcase
        end

        MUL_BH: begin
            case (mult_R_idx)
                2'd0: S1G_r <= mult_R;
                2'd1: RVX_r <= mult_R;
                default: ;
            endcase
        end

        default: ;
    endcase

    if (mult_R_idx == 2'd3) begin
        mul_phase_r <= MUL_NONE;
    end
end

// =====================================================
// ADD result commit
// Không dùng state để ghi reg 256-bit nữa
// =====================================================
if (add_done) begin
    case (add_phase_r)
        ADD_HR: begin
            case (add_tag2)
                3'd0: H_r <= add_S;
                3'd1: R_r <= add_S;
                default: ;
            endcase
        end

        ADD_XPRE: begin
            case (add_tag2)
                3'd0: twoV_r <= add_S;
                3'd1: tmpX_r <= add_S;
                default: ;
            endcase
        end

        ADD_X3: begin
            X3_calc_r <= add_S;
        end

        ADD_VX: begin
            VX_r <= add_S;
        end

        ADD_Y3: begin
            Y3_calc_r <= add_S;
        end

        default: ;
    endcase
end
                
            case (state)
                // =================================================
                // IDLE
                // =================================================
                ST_IDLE: begin
                    busy          <= 1'b0;
                    mult_load_idx <= 2'd0;

                    if (start) begin
                        busy          <= 1'b1;

                        P_r           <= P_mod;
                        IP_r          <= IP_mod;
                        N0_prime_52_r <= N0_prime_52;

                        X1_r          <= X1_in;
                        Y1_r          <= Y1_in;
                        Z1_r          <= Z1_in;

                        X2_r          <= X2_in;
                        Y2_r          <= Y2_in;
                        Z2_r          <= Z2_in;

                        mult_load_idx <= 2'd0;
                        state         <= ST_BA_START;
                    end
                end

                // =================================================
                // BA: Z1Z1, Z2Z2, Z1Z2
                // =================================================
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

                // =================================================
                // BB: U1, U2, Z1CUBE, Z2CUBE
                // =================================================
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
                            state         <= ST_BC_START;
                        end
                    end
                end

                // =================================================
                // BC: S1, S2
                // =================================================
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
                            state <= ST_H_LOAD;
                        end
                    end
                end

                // =================================================
                // H = U1 - U2
                // R = S1 - S2
                // =================================================
                ST_H_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_HR;
                    state         <= ST_H_WAIT;
                end

                ST_H_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        if (add_recv_cnt == 3'd1) begin
                            add_recv_cnt  <= 3'd0;
                            add_issue_idx <= 3'd0;
                            add_phase_r   <= ADD_NONE;
                            mult_load_idx <= 2'd0;
                            state         <= ST_BE_START;
                        end
                        else begin
                            add_recv_cnt <= add_recv_cnt + 1'b1;
                        end
                    end
                end

                // =================================================
                // BE: HH, RR, Z3
                // =================================================
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
                            state         <= ST_BF_START;
                        end
                    end
                end

                // =================================================
                // BF: G, V
                // =================================================
                ST_BF_START: begin
                    if (mult_can_issue) begin
                        if (mult_load_idx == 2'd0)
                            mul_phase_r <= MUL_BF;
                            
                        if (mult_load_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BF_WAIT;
                        end
                        else begin
                            mult_load_idx <= mult_load_idx + 1'b1;
                        end
                    end
                end

                ST_BF_WAIT: begin
                    if (mult_R_valid) begin
                        if (mult_R_idx == 2'd3) begin
                            state <= ST_2V_LOAD;
                        end
                    end
                end

                // =================================================
                // twoV = V + V
                // tmpX = RR + G
                // X3   = tmpX - twoV
                // VX   = V - X3
                // =================================================
                ST_2V_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_XPRE;
                    state         <= ST_2V_WAIT;
                end

                ST_2V_WAIT: begin
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
                        state         <= ST_VX_LOAD;
                    end
                end

                ST_VX_LOAD: begin
                    add_issue_idx <= 3'd0;
                    add_recv_cnt  <= 3'd0;
                    add_phase_r   <= ADD_VX;
                    state         <= ST_VX_WAIT;
                end

                ST_VX_WAIT: begin
                    if (add_start_c) begin
                        add_issue_idx <= add_issue_idx + 1'b1;
                    end

                    if (add_done) begin
                        add_issue_idx <= 3'd0;
                        add_recv_cnt  <= 3'd0;
                        add_phase_r   <= ADD_NONE;
                        mult_load_idx <= 2'd0;
                        state         <= ST_BH_START;
                    end
                end

                // =================================================
                // BH: S1G, RVX
                // =================================================
                ST_BH_START: begin
                    if (mult_can_issue) begin
                        if (mult_load_idx == 2'd0)
                            mul_phase_r <= MUL_BH;
                            
                        if (mult_load_idx == 2'd3) begin
                            mult_load_idx <= 2'd0;
                            state         <= ST_BH_WAIT;
                        end
                        else begin
                            mult_load_idx <= mult_load_idx + 1'b1;
                        end
                    end
                end

                ST_BH_WAIT: begin
                    if (mult_R_valid) begin
                        if (mult_R_idx == 2'd3) begin
                            state <= ST_Y3_LOAD;
                        end
                    end
                end

                // =================================================
                // Y3 = RVX - S1G
                // =================================================
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

                // =================================================
                // FINAL special cases
                // =================================================
                ST_FINAL: begin
                    if ((Z1_r == 256'd0) && (Z2_r == 256'd0)) begin
                        X3_r <= 256'd0;
                        Y3_r <= 256'd0;
                        Z3_r <= 256'd0;
                    end
                    else if (Z1_r == 256'd0) begin
                        X3_r <= X2_r;
                        Y3_r <= Y2_r;
                        Z3_r <= Z2_r;
                    end
                    else if (Z2_r == 256'd0) begin
                        X3_r <= X1_r;
                        Y3_r <= Y1_r;
                        Z3_r <= Z1_r;
                    end
                    else if ((H_r == 256'd0) && (R_r != 256'd0)) begin
                        X3_r <= 256'd0;
                        Y3_r <= 256'd0;
                        Z3_r <= 256'd0;
                    end
                    else if ((H_r == 256'd0) && (R_r == 256'd0)) begin
                        X3_r <= 256'd0;
                        Y3_r <= 256'd0;
                        Z3_r <= 256'd0;
                    end
                    else begin
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
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
