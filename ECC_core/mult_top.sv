`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2026 03:49:38 PM
// Design Name: 
// Module Name: mult_top
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


module mult_top #(
    parameter int DEPTH = 4
)(
    input  logic         clk,
    input  logic         rst_n,

    input  logic         start,
    input  logic [255:0] A_in,
    input  logic [255:0] B_in,
    input  logic [255:0] N_in,
    input  logic [255:0] IP_mod,
    input  logic [51:0]  N0_prime_52,

    output logic         busy,

    output logic [255:0] result_o,
    output logic         result_valid_o,
    output logic [1:0]   result_idx_o
);

    integer i;

    // =====================================================
    // internal control
    // =====================================================
    logic        mem_valid;
    logic        mem_busy;
    logic        batch_done;

    logic [1:0]  cnt;
    logic [2:0]  y_cur;

    logic        cnt_en;
    logic        wait_first_spack;
    logic        first_spack_hit;

    // =====================================================
    // mem address
    // =====================================================
    logic [3:0]  x_ab_arr [16];
    logic [2:0]  y_ab_arr [16];

    logic [1:0]  x_p;
    logic [2:0]  y_p;
    
    logic [3:0] x_ab_r [16];
    logic [2:0] y_ab_r [16];

    // =====================================================
    // mem outputs
    // =====================================================
    logic [16:0] Aseg_o   [16];
    logic [16:0] Sseg_o   [16];
    logic [25:0] B_lo_o   [16];
    logic [25:0] B_hi_o   [16];
    logic [16:0] Nseg_q_o [16];

    logic [51:0] A52_p;
    logic [51:0] B52_p;
    logic [51:0] S52_p;
    logic        q_in_valid_r;
    logic [51:0] q_A52_r;
    logic [51:0] q_B52_r;
    logic [51:0] q_S52_r;
    logic [51:0] q_N0_r;

    logic [1:0]  q_idx_in_r;
    logic [2:0]  q_y_in_r;

    // =====================================================
    // q_pipe
    // =====================================================
    logic        q_we;
    logic [25:0] Q_lo_q;
    logic [25:0] Q_hi_q;

    // =====================================================
    // valid chain
    // =====================================================
    logic val_d1, val_d2, val_d3, val_d4;
    logic val_add1, val_add2, val_addS;

    // =====================================================
    // tag chain
    // =====================================================
    logic [1:0] idx_nq;
    logic [2:0] y_nq;

    logic [1:0] idx_q0, idx_q1, idx_q2;//, idx_q3;
    logic [2:0] y_q0,   y_q1,   y_q2;//,   y_q3;

    logic [1:0] idx_d1, idx_d2, idx_d3, idx_d4;
    logic [2:0] y_d1,   y_d2,   y_d3,   y_d4;

    logic [1:0] idx_add1, idx_add2, idx_addS;
    logic [2:0] y_add1,   y_add2,   y_addS;

    // =====================================================
    // DSP outputs
    // =====================================================
    logic [47:0] p_nq_lo [16];
    logic [47:0] p_nq_hi [16];

    // =====================================================
    // adder tree
    // =====================================================
    logic [103:0] grp_lo_r [4];
    logic [103:0] grp_hi_r [4];

    logic [307:0] S_lo_r;
    logic [307:0] S_hi_r;
    logic [307:0] S_red_r;

    // =====================================================
    // final pack / correction
    // =====================================================

    // =====================================================
    // s_pack write-back cho y = 0..3
    // =====================================================
    logic         s_pack_we_r;
    logic [3:0]   s_pack_x_r;
    logic [2:0]   s_pack_y_r;
    logic [271:0] s_pack_data_r;

    // =====================================================
    // batch done
    // =====================================================
    logic all_done_comb;
    logic pipe_busy_comb;
    logic [2:0] result_count;

    // -----------------------------------------------------
    // mem
    // -----------------------------------------------------
    mult_mem #(
        .DEPTH(DEPTH)
    ) u_mem (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .busy        (mem_busy),
        .mem_valid   (mem_valid),
        .batch_done  (batch_done),

        .A_in        (A_in),
        .B_in        (B_in),
        .N_in        (N_in),

        .x           (x_ab_arr),
        .y           (y_ab_arr),

        .x_p         (x_p),
        .y_p         (y_p),

        .s_pack_we   (s_pack_we_r),
        .s_pack_x    (s_pack_x_r),
        .s256_in     (s_pack_data_r),

        .Aseg_o      (Aseg_o),
        .Sseg_o      (Sseg_o),
        .B_lo_o      (B_lo_o),
        .B_hi_o      (B_hi_o),

        .A52_p       (A52_p),
        .B52_p       (B52_p),
        .S52_p       (S52_p),

        .Nseg_q_o    (Nseg_q_o)
    );

    // -----------------------------------------------------
    // q_pipe input register
    // Cắt đường cnt_reg -> mux/mem -> q_pipe DSP.
    // Sau block này, q_pipe chỉ nhận input từ FF gần nó.
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_in_valid_r <= 1'b0;
            q_A52_r      <= '0;
            q_B52_r      <= '0;
            q_S52_r      <= '0;
            q_N0_r       <= '0;
            q_idx_in_r   <= '0;
            q_y_in_r     <= '0;
        end
        else if (!mem_valid) begin
            q_in_valid_r <= 1'b0;
            q_A52_r      <= '0;
            q_B52_r      <= '0;
            q_S52_r      <= '0;
            q_N0_r       <= '0;
            q_idx_in_r   <= '0;
            q_y_in_r     <= '0;
        end
        else begin
            q_in_valid_r <= cnt_en;
    
            if (cnt_en) begin
                q_A52_r    <= A52_p;
                q_B52_r    <= B52_p;
                q_S52_r    <= S52_p;
                q_N0_r     <= N0_prime_52;
    
                q_idx_in_r <= cnt;
                q_y_in_r   <= y_cur;
            end
        end
    end
    
    // -----------------------------------------------------
    // cnt / y control
    // -----------------------------------------------------
    assign cnt_en          = mem_valid && !wait_first_spack;
    assign first_spack_hit = wait_first_spack && s_pack_we_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt              <= 2'd0;
            y_cur            <= 3'd0;
            wait_first_spack <= 1'b0;
        end
        else if (!mem_valid) begin
            cnt              <= 2'd0;
            y_cur            <= 3'd0;
            wait_first_spack <= 1'b0;
        end
        else begin
            // phat 4 input cua 1 vong y
            if (cnt_en) begin
                if (cnt == 2'd3) begin
                    cnt              <= cnt;
                    wait_first_spack <= 1'b1;
                end
                else begin
                    cnt <= cnt + 1'b1;
                end
            end

            // gap s_pack dau tien thi mo vong y moi
            if (first_spack_hit) begin
                y_cur            <= y_cur + 1'b1;
                cnt              <= 2'd0;
                wait_first_spack <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------
    // address comb
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k < 16; k = k + 1) begin
                x_ab_r[k] <= '0;
                y_ab_r[k] <= '0;
            end
        end
        else begin
            // Prefetch địa chỉ đọc AB trước 1 clock.
            // đúng lúc q_pipe xuất Q.
            for (int k = 0; k < 16; k = k + 1) begin
                x_ab_r[k] <= {2'b00, idx_q0};
                y_ab_r[k] <= y_q0;
            end
        end
    end
    
    always_comb begin
        x_p = cnt;
        y_p = y_cur;

        for (int k = 0; k < 16; k = k + 1) begin
            x_ab_arr[k] = x_ab_r[k];
            y_ab_arr[k] = y_ab_r[k];
        end
    end

    // -----------------------------------------------------
    // q_pipe
    // -----------------------------------------------------
    q_pipe u_q_pipe (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (q_in_valid_r),
        .A_mod_uk (q_A52_r),
        .Bi       (q_B52_r),
        .S_lo     (q_S52_r),
        .N0_prime_52  (q_N0_r),
        .q_we     (q_we),
        .Q_lo     (Q_lo_q),
        .Q_hi     (Q_hi_q)
    );

    // -----------------------------------------------------
    // DSP chain
    // -----------------------------------------------------
            logic [47:0] p_ab_lo [16];
            logic [47:0] pcout_ab_lo [16];
            logic [47:0] p_ab_hi [16];
            logic [47:0] pcout_ab_hi [16];    
    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : GEN_PAIR
            dsp_macro_0 U_DSP_AB_LO (
                .CLK   (clk),
                .A     ({1'b0, B_lo_o[g]}),
                .B     ({1'b0, Aseg_o[g]}),
                .C     ({31'd0, Sseg_o[g]}),
                .P     (p_ab_lo[g]),
                .PCOUT (pcout_ab_lo[g])
            );

            dsp_macro_1 U_DSP_NQ_LO (
                .CLK   (clk),
                .PCIN  (pcout_ab_lo[g]),
                .A     ({1'b0, Q_lo_q}),
                .B     ({1'b0, Nseg_q_o[g]}),
                .P     (p_nq_lo[g])
            );

            dsp_macro_2 U_DSP_AB_HI (
                .CLK   (clk),
                .A     ({1'b0, B_hi_o[g]}),
                .B     ({1'b0, Aseg_o[g]}),
                .P     (p_ab_hi[g]),
                .PCOUT (pcout_ab_hi[g])
            );

            dsp_macro_3 U_DSP_NQ_HI (
                .CLK   (clk),
                .PCIN  (pcout_ab_hi[g]),
                .A     ({1'b0, Q_hi_q}),
                .B     ({1'b0, Nseg_q_o[g]}),
                .P     (p_nq_hi[g])
            );
        end
    endgenerate

    // -----------------------------------------------------
    // tag / valid / delay
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx_nq <= 2'd0; y_nq <= 3'd0;
            idx_q0 <= 2'd0; y_q0 <= 3'd0;
            idx_q1 <= 2'd0; y_q1 <= 3'd0;
            idx_q2 <= 2'd0; y_q2 <= 3'd0;
            //idx_q3 <= 2'd0; y_q3 <= 3'd0;

            idx_d1 <= 2'd0; y_d1 <= 3'd0;
            idx_d2 <= 2'd0; y_d2 <= 3'd0;
            idx_d3 <= 2'd0; y_d3 <= 3'd0;
            idx_d4 <= 2'd0; y_d4 <= 3'd0;

            idx_add1 <= 2'd0; y_add1 <= 3'd0;
            idx_add2 <= 2'd0; y_add2 <= 3'd0;
            idx_addS <= 2'd0; y_addS <= 3'd0;

            val_d1   <= 1'b0;
            val_d2   <= 1'b0;
            val_d3   <= 1'b0;
            val_d4   <= 1'b0;
            val_add1 <= 1'b0;
            val_add2 <= 1'b0;
            val_addS <= 1'b0;

        end
        else if (!mem_valid) begin
            idx_nq <= 2'd0; y_nq <= 3'd0;
            idx_q0 <= 2'd0; y_q0 <= 3'd0;
            idx_q1 <= 2'd0; y_q1 <= 3'd0;
            idx_q2 <= 2'd0; y_q2 <= 3'd0;
            //idx_q3 <= 2'd0; y_q3 <= 3'd0;
                    
            idx_d1 <= 2'd0; y_d1 <= 3'd0;
            idx_d2 <= 2'd0; y_d2 <= 3'd0;
            idx_d3 <= 2'd0; y_d3 <= 3'd0;
            idx_d4 <= 2'd0; y_d4 <= 3'd0;

            idx_add1 <= 2'd0; y_add1 <= 3'd0;
            idx_add2 <= 2'd0; y_add2 <= 3'd0;
            idx_addS <= 2'd0; y_addS <= 3'd0;

            val_d1   <= 1'b0;
            val_d2   <= 1'b0;
            val_d3   <= 1'b0;
            val_d4   <= 1'b0;
            val_add1 <= 1'b0;
            val_add2 <= 1'b0;
            val_addS <= 1'b0;

        end
        else begin
            if (q_in_valid_r) begin
                idx_q0 <= q_idx_in_r;
                y_q0   <= q_y_in_r;
            end

            idx_q1 <= idx_q0;
            y_q1   <= y_q0;

            idx_q2 <= idx_q1;
            y_q2   <= y_q1;

            //idx_q3 <= idx_q2;
            //y_q3   <= y_q2;

            idx_nq <= idx_q2;
            y_nq   <= y_q2;

            idx_d1   <= idx_nq;   y_d1   <= y_nq;
            idx_d2   <= idx_d1;   y_d2   <= y_d1;
            idx_d3   <= idx_d2;   y_d3   <= y_d2;
            idx_d4   <= idx_d3;   y_d4   <= y_d3;
            idx_add1 <= idx_d4;   y_add1 <= y_d4;
            idx_add2 <= idx_add1; y_add2 <= y_add1;
            idx_addS <= idx_add2; y_addS <= y_add2;

            val_d1   <= q_we;
            val_d2   <= val_d1;
            val_d3   <= val_d2;
            val_d4   <= val_d3;
            val_add1 <= val_d4;
            val_add2 <= val_add1;
            val_addS <= val_add2;

        end
    end

    // -----------------------------------------------------
    // ADDER TREE TIER 1
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        grp_lo_r[0] <= '0; grp_lo_r[1] <= '0; grp_lo_r[2] <= '0; grp_lo_r[3] <= '0;
        grp_hi_r[0] <= '0; grp_hi_r[1] <= '0; grp_hi_r[2] <= '0; grp_hi_r[3] <= '0;
    end
    else begin
        grp_lo_r[0] <= ({56'd0, p_nq_lo[0]})
                     + (({56'd0, p_nq_lo[1]}) << 17)
                     + (({56'd0, p_nq_lo[2]}) << 34)
                     + (({56'd0, p_nq_lo[3]}) << 51);

        grp_lo_r[1] <= ({56'd0, p_nq_lo[4]})
                     + (({56'd0, p_nq_lo[5]}) << 17)
                     + (({56'd0, p_nq_lo[6]}) << 34)
                     + (({56'd0, p_nq_lo[7]}) << 51);

        grp_lo_r[2] <= ({56'd0, p_nq_lo[8]})
                     + (({56'd0, p_nq_lo[9]}) << 17)
                     + (({56'd0, p_nq_lo[10]}) << 34)
                     + (({56'd0, p_nq_lo[11]}) << 51);

        grp_lo_r[3] <= ({56'd0, p_nq_lo[12]})
                     + (({56'd0, p_nq_lo[13]}) << 17)
                     + (({56'd0, p_nq_lo[14]}) << 34)
                     + (({56'd0, p_nq_lo[15]}) << 51);

        grp_hi_r[0] <= ({56'd0, p_nq_hi[0]})
                     + (({56'd0, p_nq_hi[1]}) << 17)
                     + (({56'd0, p_nq_hi[2]}) << 34)
                     + (({56'd0, p_nq_hi[3]}) << 51);

        grp_hi_r[1] <= ({56'd0, p_nq_hi[4]})
                     + (({56'd0, p_nq_hi[5]}) << 17)
                     + (({56'd0, p_nq_hi[6]}) << 34)
                     + (({56'd0, p_nq_hi[7]}) << 51);

        grp_hi_r[2] <= ({56'd0, p_nq_hi[8]})
                     + (({56'd0, p_nq_hi[9]}) << 17)
                     + (({56'd0, p_nq_hi[10]}) << 34)
                     + (({56'd0, p_nq_hi[11]}) << 51);

        grp_hi_r[3] <= ({56'd0, p_nq_hi[12]})
                     + (({56'd0, p_nq_hi[13]}) << 17)
                     + (({56'd0, p_nq_hi[14]}) << 34)
                     + (({56'd0, p_nq_hi[15]}) << 51);
        end
    end

    // -----------------------------------------------------
    // ADDER TREE TIER 2
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            S_lo_r <= '0;
            S_hi_r <= '0;
        end
        else begin
            S_lo_r <= ({204'd0, grp_lo_r[0]})
                    + (({204'd0, grp_lo_r[1]}) << 68)
                    + (({204'd0, grp_lo_r[2]}) << 136)
                    + (({204'd0, grp_lo_r[3]}) << 204);

            S_hi_r <= ({204'd0, grp_hi_r[0]})
                    + (({204'd0, grp_hi_r[1]}) << 68)
                    + (({204'd0, grp_hi_r[2]}) << 136)
                    + (({204'd0, grp_hi_r[3]}) << 204);
        end
    end

    // -----------------------------------------------------
    // ADDS
    // S = (((S_lo >> 26) + S_hi) >> 26)
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            S_red_r <= '0;
        else if (!mem_valid)
            S_red_r <= '0;
        else
            S_red_r <= (((S_lo_r >> 26) + S_hi_r) >> 26);
    end

    // -----------------------------------------------------
    // final correction
    // lấy kết quả [255:0] sau hiệu chỉnh
    // -----------------------------------------------------
    logic        final_job_fire;

    logic [271:0] final_s272_w;
    logic [255:0] final_base_w;
    logic         final_need_w;

    logic [255:0] fix_sum;
    logic         fix_done;

    // delay song song voi pipeline addsub
    logic        fix_v0, fix_v1, fix_v2;
    logic [255:0] base_d0, base_d1, base_d2;
    logic         need_d0, need_d1, need_d2;
    logic [1:0]   idx_dl0,  idx_dl1,  idx_dl2;
    
    assign final_s272_w = S_red_r[271:0];
    assign final_base_w = final_s272_w[255:0];
    assign final_need_w = final_s272_w[256];
    assign final_job_fire = val_addS && (y_addS == 3'd4) && (idx_addS < DEPTH);

    addsub_256 U_ADD_ONE_MONT_PIPE (
        .clk   (clk),
        .rst_n (rst_n),

        .start (final_job_fire),

        .A     (final_base_w),
        .B     (IP_mod),
        .P     (N_in),
        .IP    (IP_mod),
        .SUB   (1'b0),

        .S     (fix_sum),
        .done  (fix_done)
    );
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fix_v0 <= 1'b0;
            fix_v1 <= 1'b0;
            fix_v2 <= 1'b0;

            base_d0 <= '0;
            base_d1 <= '0;
            base_d2 <= '0;

            need_d0 <= 1'b0;
            need_d1 <= 1'b0;
            need_d2 <= 1'b0;

            idx_dl0 <= '0;
            idx_dl1 <= '0;
            idx_dl2 <= '0;
        end
        else if (!mem_valid) begin
            fix_v0 <= 1'b0;
            fix_v1 <= 1'b0;
            fix_v2 <= 1'b0;
        end
        else begin
            // valid shift, căn theo addsub_256_pipe3
            fix_v0 <= final_job_fire;
            fix_v1 <= fix_v0;
            fix_v2 <= fix_v1;

            // stage 0: chốt dữ liệu final ban đầu
            if (final_job_fire) begin
                base_d0 <= final_base_w;
                need_d0 <= final_need_w;
                idx_dl0  <= idx_addS;
            end

            // stage 1
            if (fix_v0) begin
                base_d1 <= base_d0;
                need_d1 <= need_d0;
                idx_dl1  <= idx_dl0;
            end

            // stage 2
            if (fix_v1) begin
                base_d2 <= base_d1;
                need_d2 <= need_d1;
                idx_dl2  <= idx_dl1;
            end
        end
    end

    // -----------------------------------------------------
    // S_PACK
    // y = 0..3 mới ghi ngược về mem
    // y = 4 chỉ xuất result, không ghi mem nữa
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_pack_we_r   <= 1'b0;
            s_pack_x_r    <= '0;
            s_pack_y_r    <= '0;
            s_pack_data_r <= '0;
        end
        else if (!mem_valid) begin
            s_pack_we_r   <= 1'b0;
            s_pack_x_r    <= '0;
            s_pack_y_r    <= '0;
            s_pack_data_r <= '0;
        end
        else begin
            s_pack_we_r   <= val_addS && (y_addS < 3'd4);
            s_pack_x_r    <= {2'b00, idx_addS};
            s_pack_y_r    <= y_addS;
            s_pack_data_r <= S_red_r[271:0];
        end
    end

    // -----------------------------------------------------
    // final result
    // y = 4 thì lấy s256_final_pack ra ngoài
    // -----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_o       <= '0;
            result_idx_o   <= '0;
            result_valid_o <= 1'b0;
            result_count   <= '0;
        end
        else if (batch_done) begin
            result_o       <= '0;
            result_idx_o   <= '0;
            result_valid_o <= 1'b0;
            result_count   <= '0;
        end
        else begin
            result_valid_o <= 1'b0;

            // fix_v2 đã delay theo addsub pipeline.
            // fix_sum là kết quả đã cộng one_mont mod P.
            if (fix_v2) begin
                result_o       <= need_d2 ? fix_sum : base_d2;
                result_idx_o   <= idx_dl2;
                result_valid_o <= 1'b1;

                if (result_count < DEPTH)
                    result_count <= result_count + 1'b1;
            end
        end
    end

    // -----------------------------------------------------
    // batch_done + busy
    // -----------------------------------------------------
    always_comb begin

    all_done_comb = (result_count == DEPTH);

    pipe_busy_comb = cnt_en |
                     (wait_first_spack && (y_cur < 3'd4)) |
                     q_we | val_d1 | val_d2 | val_d3 | val_d4 |
                     val_add1 | val_add2 | val_addS | final_job_fire | fix_v0 | fix_v1 | fix_v2 | s_pack_we_r;

        batch_done = mem_valid && all_done_comb && !pipe_busy_comb;
    end

    assign busy = mem_valid | pipe_busy_comb;

endmodule
