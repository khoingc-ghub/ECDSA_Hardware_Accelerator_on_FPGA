`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 06:53:53 PM
// Design Name: 
// Module Name: mult_mem
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


module mult_mem #(
    parameter int DEPTH = 16
)(
    input  logic clk,
    input  logic rst_n,

    //-------------------
    // control
    //-------------------
    input  logic start,
    output logic busy,
    output logic mem_valid,
    input  logic batch_done,

    //-------------------
    // input stream
    //-------------------
    input  logic [255:0] A_in,
    input  logic [255:0] B_in,
    input  logic [255:0] S_in,
    input  logic [255:0] N_in,

    //-------------------
    // read address bo AB
    //-------------------
    input  logic [3:0] x   [16],
    input  logic [2:0] y   [16],

    //-------------------
    // read address bo Q-pipe
    //-------------------
    input  logic [3:0] x_p,
    input  logic [2:0] y_p,

    //-------------------
    // read address bo NQ
    //-------------------
    input  logic [3:0] x_q [16],
    input  logic [3:0] x_s [16],

    input  logic [47:0] p_nq_lo_in [16],
    input  logic [47:0] p_nq_hi_in [16],
    input  logic        p_nq_we    [16],

    //-------------------
    // Q write tu top
    //-------------------
    input  logic        q_we,
    input  logic [3:0]  q_x,
    input  logic [51:0] q52_in,
    input  logic [25:0] qlo_in,
    input  logic [25:0] qhi_in,

    //-------------------
    // S write-back
    //-------------------
    input  logic        s_pack_we,
    input  logic [3:0]  s_pack_x,
    input  logic [271:0] s256_in,

    //-------------------
    // outputs AB
    //-------------------
    output logic [16:0] Aseg_o [16],
    output logic [16:0] Sseg_o [16],

    output logic [25:0] B_lo_o [16],
    output logic [25:0] B_hi_o [16],

    //-------------------
    // outputs cho Q-pipe
    //-------------------
    output logic [51:0] A52_p,
    output logic [51:0] B52_p,
    output logic [51:0] S52_p,

    output logic [302:0] S_pack_lo_o [DEPTH],
    output logic [302:0] S_pack_hi_o [DEPTH],
    output logic         S_pack_lo_valid_o [DEPTH],
    output logic         S_pack_hi_valid_o [DEPTH],

    //-------------------
    // outputs NQ
    //-------------------
    output logic [16:0] Nseg_q_o [16],

    output logic [51:0] Q52_q_o  [16],
    output logic [25:0] Q_lo_q_o [16],
    output logic [25:0] Q_hi_q_o [16]
);

    //---------------------------------
    // memory
    //---------------------------------
    logic [16:0] Aseg_mem [DEPTH][16];
    logic [16:0] Sseg_mem [DEPTH][16];
    logic [16:0] Nseg_mem [DEPTH][16];

    // A, S theo x
    logic [51:0] A52_mem  [DEPTH];
    logic [51:0] S52_mem  [DEPTH];

    // B theo x,y
    logic [51:0] B52_mem  [DEPTH][5];
    logic [25:0] B_lo_mem [DEPTH][5];
    logic [25:0] B_hi_mem [DEPTH][5];

    // Q theo x_q
    logic [51:0] Q52_mem  [DEPTH];
    logic [25:0] Q_lo_mem [DEPTH];
    logic [25:0] Q_hi_mem [DEPTH];

    // Gom P_nq thanh packed word
    // DSP 0..14 : moi DSP 17 bit
    // DSP 15    : giu full 48 bit (thuc te dang dung [46:0] theo code goc)
    logic [302:0] S_pack_lo_mem [DEPTH];
    logic [302:0] S_pack_hi_mem [DEPTH];

    logic         S_pack_lo_valid [DEPTH];
    logic         S_pack_hi_valid [DEPTH];

    //---------------------------------
    // write counter
    //---------------------------------
    logic [3:0] wr_cnt;

    integer i, j, t_s, m, w, d;

    //---------------------------------
    // mem_valid len ngay tu start dau
    //---------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_valid <= 1'b0;
        else if (batch_done)
            mem_valid <= 1'b0;
        else if (start)
            mem_valid <= 1'b1;
    end

    //---------------------------------
    // wr_cnt / busy
    //---------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_cnt <= '0;
            busy   <= 1'b0;
        end
        else if (batch_done) begin
            wr_cnt <= '0;
            busy   <= 1'b0;
        end
        else begin
            if (start && !busy) begin
                if (wr_cnt == DEPTH-1) begin
                    busy <= 1'b1;
                end
                else begin
                    wr_cnt <= wr_cnt + 1'b1;
                end
            end
        end
    end

    //---------------------------------
    // WRITE A / N / A52 / B vao mem
    //---------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                A52_mem[i] <= '0;
                for (j = 0; j < 16; j = j + 1) begin
                    Aseg_mem[i][j] <= '0;
                    Nseg_mem[i][j] <= '0;
                end
                for (w = 0; w < 5; w = w + 1) begin
                    B52_mem [i][w] <= '0;
                    B_lo_mem[i][w] <= '0;
                    B_hi_mem[i][w] <= '0;
                end
            end
        end
        else if (batch_done) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                A52_mem[i] <= '0;
                for (j = 0; j < 16; j = j + 1) begin
                    Aseg_mem[i][j] <= '0;
                    Nseg_mem[i][j] <= '0;
                end
                for (w = 0; w < 5; w = w + 1) begin
                    B52_mem [i][w] <= '0;
                    B_lo_mem[i][w] <= '0;
                    B_hi_mem[i][w] <= '0;
                end
            end
        end
        else begin
            if (start && !busy) begin
                // Aseg / Nseg
                for (i = 0; i < 15; i = i + 1) begin
                    Aseg_mem[wr_cnt][i] <= A_in[17*i +: 17];
                    Nseg_mem[wr_cnt][i] <= N_in[17*i +: 17];
                end

                Aseg_mem[wr_cnt][15] <= {16'b0, A_in[255]};
                Nseg_mem[wr_cnt][15] <= {16'b0, N_in[255]};

                // A52
                A52_mem[wr_cnt] <= A_in[0 +: 52];

                // B theo 5 word
                for (j = 0; j < 4; j = j + 1) begin
                    B52_mem [wr_cnt][j] <= B_in[52*j      +: 52];
                    B_lo_mem[wr_cnt][j] <= B_in[52*j      +: 26];
                    B_hi_mem[wr_cnt][j] <= B_in[52*j + 26 +: 26];
                end

                B52_mem [wr_cnt][4] <= {4'b0, B_in[255:208]};
                B_lo_mem[wr_cnt][4] <= B_in[233:208];
                B_hi_mem[wr_cnt][4] <= {4'b0, B_in[255:234]};
            end
        end
    end

    //---------------------------------
    // WRITE Sseg / S52
    // Gop ve 1 always_ff de tranh loi synth multi-write
    //---------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                S52_mem[i] <= '0;
                for (j = 0; j < 16; j = j + 1) begin
                    Sseg_mem[i][j] <= '0;
                end
            end
        end
        else if (batch_done) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                S52_mem[i] <= '0;
                for (j = 0; j < 16; j = j + 1) begin
                    Sseg_mem[i][j] <= '0;
                end
            end
        end
        else begin
            // nap S ban dau khi stream input vao
            if (start && !busy) begin
                for (t_s = 0; t_s < 15; t_s = t_s + 1) begin
                    Sseg_mem[wr_cnt][t_s] <= S_in[17*t_s +: 17];
                end
                Sseg_mem[wr_cnt][15] <= {16'b0, S_in[255]};
                S52_mem[wr_cnt]      <= S_in[0 +: 52];
            end

            // ghi de S moi tu ST_PACK
            // neu cung chu ky co ca start va s_pack_we,
            // lenh ben duoi se co uu tien neu trung cung phan tu
            if (s_pack_we) begin
                for (t_s = 0; t_s < 16; t_s = t_s + 1) begin
                    Sseg_mem[s_pack_x][t_s] <= s256_in[17*t_s +: 17];
                end
                S52_mem[s_pack_x] <= s256_in[0 +: 52];
            end
        end
    end

    //---------------------------------
    // WRITE Q vao mem
    //---------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (d = 0; d < DEPTH; d = d + 1) begin
                Q52_mem[d] <= '0;
                Q_lo_mem[d] <= '0;
                Q_hi_mem[d] <= '0;
            end
        end
        else if (batch_done) begin
            for (d = 0; d < DEPTH; d = d + 1) begin
                Q52_mem[d] <= '0;
                Q_lo_mem[d] <= '0;
                Q_hi_mem[d] <= '0;
            end
        end
        else if (q_we) begin
            Q52_mem[q_x] <= q52_in;
            Q_lo_mem[q_x] <= qlo_in;
            Q_hi_mem[q_x] <= qhi_in;
        end
    end

    //---------------------------------
    // WRITE P_nq_lo / P_nq_hi vao mem theo x_s
    // DSP 0..14 : lay 17 bit
    // DSP 15    : giu full 48 bit (code goc dang ghi [46:0])
    //---------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < DEPTH; m = m + 1) begin
                S_pack_lo_mem[m]   <= '0;
                S_pack_hi_mem[m]   <= '0;
                S_pack_lo_valid[m] <= 1'b0;
                S_pack_hi_valid[m] <= 1'b0;
            end
        end
        else if (batch_done || !mem_valid) begin
            for (m = 0; m < DEPTH; m = m + 1) begin
                S_pack_lo_mem[m]   <= '0;
                S_pack_hi_mem[m]   <= '0;
                S_pack_lo_valid[m] <= 1'b0;
                S_pack_hi_valid[m] <= 1'b0;
            end
        end
        else begin
            // ghi data tung lane
            for (m = 0; m < 16; m = m + 1) begin
                if (p_nq_we[m]) begin
                    if (m < 15) begin
                        S_pack_lo_mem[x_s[m]][17*m +: 17] <= p_nq_lo_in[m][16:0];
                        S_pack_hi_mem[x_s[m]][17*m +: 17] <= p_nq_hi_in[m][16:0];
                    end
                    else begin
                        S_pack_lo_mem[x_s[m]][17*15 +: 48] <= p_nq_lo_in[m][46:0];
                        S_pack_hi_mem[x_s[m]][17*15 +: 48] <= p_nq_hi_in[m][46:0];
                    end
                end
            end

            // lane 0 bat dau ghi word moi -> clear valid cua word do
            if (p_nq_we[0]) begin
                S_pack_lo_valid[x_s[0]] <= 1'b0;
                S_pack_hi_valid[x_s[0]] <= 1'b0;
            end

            // lane 15 la lane cuoi cung ghi vao 1 word -> set valid
            if (p_nq_we[15]) begin
                S_pack_lo_valid[x_s[15]] <= 1'b1;
                S_pack_hi_valid[x_s[15]] <= 1'b1;
            end
        end
    end

    //---------------------------------
    // READ cho AB va NQ
    //---------------------------------
    genvar k;
    generate
      for (k = 0; k < 16; k = k + 1) begin : GEN_READ
        always_comb begin
          Aseg_o[k]   = '0;
          Sseg_o[k]   = '0;
          B_lo_o[k]   = '0;
          B_hi_o[k]   = '0;

          Nseg_q_o[k] = '0;
          Q52_q_o[k]  = '0;
          Q_lo_q_o[k] = '0;
          Q_hi_q_o[k] = '0;

          if (mem_valid) begin
            Aseg_o[k] = Aseg_mem[x[k]][k];
            Sseg_o[k] = Sseg_mem[x[k]][k];

            B_lo_o[k] = B_lo_mem[x[k]][y[k]];
            B_hi_o[k] = B_hi_mem[x[k]][y[k]];

            Nseg_q_o[k] = Nseg_mem[x_q[k]][k];

            Q52_q_o[k]  = Q52_mem[x_q[k]];
            Q_lo_q_o[k] = Q_lo_mem[x_q[k]];
            Q_hi_q_o[k] = Q_hi_mem[x_q[k]];
          end
        end
      end
    endgenerate

    //---------------------------------
    // READ cho Q-pipe
    //---------------------------------
    always_comb begin
        A52_p = '0;
        B52_p = '0;
        S52_p = '0;

        if (mem_valid) begin
            A52_p = A52_mem[x_p];
            B52_p = B52_mem[x_p][y_p];
            S52_p = S52_mem[x_p];
        end
    end

    //---------------------------------
    // EXPORT bank gom S ra ngoai
    //---------------------------------
    genvar s;
    generate
      for (s = 0; s < DEPTH; s = s + 1) begin : GEN_SPACK_OUT
        always_comb begin
          S_pack_lo_o[s]       = S_pack_lo_mem[s];
          S_pack_hi_o[s]       = S_pack_hi_mem[s];
          S_pack_lo_valid_o[s] = S_pack_lo_valid[s];
          S_pack_hi_valid_o[s] = S_pack_hi_valid[s];
        end
      end
    endgenerate

endmodule
