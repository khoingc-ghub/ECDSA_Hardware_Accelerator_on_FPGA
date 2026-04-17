`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 06:53:28 PM
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
  parameter int DEPTH = 16
)(
  input  logic         clk,
  input  logic         rst_n,

  input  logic         start,
  input  logic [255:0] A_in,
  input  logic [255:0] B_in,
  input  logic [255:0] S_in,
  input  logic [255:0] N_in,

  output logic         busy,
  /*output logic         mem_valid,

  output logic [3:0]   x_dbg  [16],
  output logic [2:0]   y_dbg  [16],
  output logic [3:0]   xp_dbg,
  output logic [2:0]   yp_dbg,
  output logic [3:0]   xq_dbg [16],
  output logic [2:0]   yq_dbg [16],
  output logic [3:0]   xs_dbg [16],
  output logic [2:0]   ys_dbg [16],

  output logic [16:0]  Aseg [16],
  output logic [16:0]  Sseg [16],

  output logic [25:0]  B_lo [16],
  output logic [25:0]  B_hi [16],

  output logic [51:0]  A52_p,
  output logic [51:0]  B52_p,
  output logic [51:0]  S52_p,

  output logic [16:0]  Nseg [16],

  output logic [51:0]  Q52  [16],
  output logic [25:0]  Q_lo [16],
  output logic [25:0]  Q_hi [16],*/
  
  output logic [255:0] S_out_final [DEPTH],
  output logic         S_out_final_valid
);
  logic         mem_valid;
  logic [16:0]  Aseg [16];
  logic [16:0]  Sseg [16];

  logic [25:0]  B_lo [16];
  logic [25:0]  B_hi [16];

  logic [51:0]  A52_p;
  logic [51:0]  B52_p;
  logic [51:0]  S52_p;

  logic [16:0]  Nseg [16];

  logic [51:0]  Q52  [16];
  logic [25:0]  Q_lo [16];
  logic [25:0]  Q_hi [16];
  
  // =========================================================
  //  counter AB
  // =========================================================
  logic batch_done;
  logic [3:0]  x   [16];
  logic [2:0]  y   [16];

  // =========================================================
  //  counter doc N/Q, tre 4 clk
  // =========================================================
  logic [3:0]  x_q [16];
  
  logic [3:0] x_s [16];

  // =========================================================
  //  counter rieng cho Q-pipe
  // =========================================================
  logic        qcalc_run;
  logic [3:0]  x_p;
  logic [2:0]  y_p;

  logic [3:0]  x_p_d1, x_p_d2;

  logic        q_in_valid;
  logic        q_we_pipe;
  logic [51:0] q52_pipe;
  logic [25:0] qlo_pipe;
  logic [25:0] qhi_pipe;
  
  // =========================================================
  // DSP lanes
  // =========================================================
  logic [47:0] p_ab_lo     [16];
  logic [47:0] pcout_ab_lo [16];

  logic [47:0] p_ab_hi     [16];
  logic [47:0] pcout_ab_hi [16];

  logic [47:0] p_nq_lo     [16];
  logic [47:0] pcout_nq_lo [16];

  logic [47:0] p_nq_hi     [16];
  logic [47:0] pcout_nq_hi [16];
  
  logic [302:0] S_pack_lo [DEPTH];
  logic [302:0] S_pack_hi [DEPTH];
  logic         S_pack_lo_valid [DEPTH];
  logic         S_pack_hi_valid [DEPTH];

  integer i;
  typedef enum logic [1:0] {
    ST_IDLE = 2'd0,
    ST_RUN  = 2'd1,
    ST_PACK = 2'd2,
    ST_DONE = 2'd3
  } state_t;

  state_t state;

  logic [31:0] t_round;
  logic [2:0]  y_round;

  logic [15:0] x_done;
  logic [15:0] xq_done;
  logic [15:0] xs_done;

  logic        qcalc_done_round;
  logic        round_done_all;

  // stage pack S (placeholder)
  logic        pack_done;
  logic [3:0]  pack_cnt;  
  logic        p_nq_we [16];
  
  assign batch_done = (state == ST_DONE);
  
  assign round_done_all = (&x_done) & (&xq_done) & (&xs_done) & qcalc_done_round;
  
  assign q_in_valid = mem_valid && (state == ST_RUN) && qcalc_run;
  
  integer w;
  always_comb begin
    for (w = 0; w < 16; w = w + 1) begin
      p_nq_we[w] = mem_valid && (state == ST_RUN) && (t_round > (4*w + 8)) && !xs_done[w];
    end
  end
  
  //
    localparam int S_PACK_W = 303;
    localparam int S272_W   = 272;

    logic [S_PACK_W:0] s_pack_lo_shr17;
    logic [S_PACK_W:0] s_pack_add;
    logic [S_PACK_W:0] s_pack_post;
    logic [271:0] s256_in_pack;

    logic        s_pack_we;
    logic [3:0]  s_pack_x;
    logic s_pack_word_valid;
    logic [255:0] s256_fix_pack;
    logic [255:0] s256_final_pack;

    logic         need_plus_one_pack;
    localparam logic [255:0] P_fix_r = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    localparam logic [255:0] one_mont_r = 256'h00000000FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000001;
    addsub_256 U_ADD_ONE_MONT (
        .A   (s256_in_pack[255:0]),
        .B   (one_mont_r),
        .P   (P_fix_r),
        .SUB (1'b0),
        .S   (s256_fix_pack)
    );
    
    assign s_pack_word_valid = S_pack_lo_valid[pack_cnt] & S_pack_hi_valid[pack_cnt];
    assign need_plus_one_pack = s256_in_pack[256];

    always_comb begin
        s_pack_we = (state == ST_PACK) && !pack_done;
        s_pack_x  = pack_cnt;
        s_pack_add         = '0;
        s_pack_post        = '0;
        s256_in_pack       = '0;
        s256_final_pack    = '0;

        if (s_pack_word_valid) begin
            s_pack_add  = (({2'b0, S_pack_lo[pack_cnt]} >> 26) + {2'b0, S_pack_hi[pack_cnt]});
            s_pack_post = (s_pack_add >> 26);
            s256_in_pack = s_pack_post[259:0];
            s256_final_pack = need_plus_one_pack ? s256_fix_pack : s256_in_pack;
        end
    end
    
    assign S_out_final_valid = (state == ST_DONE);
    
    integer sf;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (sf = 0; sf < DEPTH; sf = sf + 1) begin
                S_out_final[sf] <= '0;
            end
        end
        else if (s_pack_we && (y_round == 3'd4)) begin
            S_out_final[s_pack_x] <= s256_final_pack;
        end
    end
  
  // =========================================================
  // counter 
  // =========================================================

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= ST_IDLE;
      t_round          <= '0;
      y_round          <= '0;

      qcalc_run        <= 1'b0;
      qcalc_done_round <= 1'b0;

      x_p              <= '0;
      y_p              <= '0;
      x_p_d1           <= '0;
      x_p_d2           <= '0;

      pack_done        <= 1'b0;
      pack_cnt         <= '0;

      for (i = 0; i < 16; i = i + 1) begin
        x[i]      <= '0;
        y[i]      <= '0;
        x_q[i]    <= '0;
        x_s[i]    <= '0;
        
        x_done[i]  <= 1'b0;
        xq_done[i] <= 1'b0;
        xs_done[i] <= 1'b0;
      end
    end
    else begin
      // mặc định delay cho q_x writeback
      x_p_d1 <= x_p;
      x_p_d2 <= x_p_d1;

      if (!mem_valid) begin
        state            <= ST_IDLE;
        t_round          <= '0;
        y_round          <= '0;

        qcalc_run        <= 1'b0;
        qcalc_done_round <= 1'b0;

        x_p              <= '0;
        y_p              <= '0;
        x_p_d1           <= '0;
        x_p_d2           <= '0;
        
        pack_done        <= 1'b0;
        pack_cnt         <= '0;

        for (i = 0; i < 16; i = i + 1) begin
          x[i]      <= '0;
          y[i]      <= '0;
          x_q[i]    <= '0;
          x_s[i]    <= '0;

          x_done[i]  <= 1'b0;
          xq_done[i] <= 1'b0;
          xs_done[i] <= 1'b0;
        end
      end
      else begin
        case (state)

          // =========================================
          // Wait mem_valid
          // =========================================
          ST_IDLE: begin
            state            <= ST_RUN;
            t_round          <= '0;
            y_round          <= 3'd0;

            qcalc_run        <= 1'b1;
            qcalc_done_round <= 1'b0;

            x_p              <= 4'd0; 
            y_p              <= 3'd0;

            pack_done        <= 1'b0;
            pack_cnt         <= '0;

            for (i = 0; i < 16; i = i + 1) begin
              x[i]      <= 4'd0;
              y[i]      <= 3'd0;
              x_q[i]    <= 4'd0;
              x_s[i]    <= 4'd0;

              x_done[i]  <= 1'b0;
              xq_done[i] <= 1'b0;
              xs_done[i] <= 1'b0;
            end
          end

          // =========================================
          // Stage RUN
          // =========================================
          ST_RUN: begin
            t_round <= t_round + 1'b1;

            //  y chung
            y_p <= y_round;
            for (i = 0; i < 16; i = i + 1) begin
              y[i]   <= y_round;
            end

          // -----------------------------
          // day A/S/B: start tai 4*i
          // counter A x Bi
          // -----------------------------
            for (i = 0; i < 16; i = i + 1) begin
              if (!x_done[i]) begin
                if (t_round > (4*i)) begin
                  if (x[i] == 4'd15) begin
                    x[i]      <= 4'd15;   
                    x_done[i] <= 1'b1;    
                  end
                  else begin
                    x[i] <= x[i] + 1'b1;
                  end
                end
              end
            end

            // -----------------------------
            // day N/Q: start tai 4*i + 4
            // counter ghi N x Qi
            // -----------------------------
            for (i = 0; i < 16; i = i + 1) begin
              if (!xq_done[i]) begin
                if (t_round > (4*i + 4)) begin
                  if (x_q[i] == 4'd15) begin
                    x_q[i]     <= 4'd15;
                    xq_done[i] <= 1'b1;
                  end
                  else begin
                    x_q[i] <= x_q[i] + 1'b1;
                  end
                end
              end
            end

            // -----------------------------
            //  S start tai 4*i + 8
            //  counter de ghi S vao mem
            // -----------------------------
            for (i = 0; i < 16; i = i + 1) begin
              if (!xs_done[i]) begin
                if (t_round > (4*i + 8)) begin
                  if (x_s[i] == 4'd15) begin
                    x_s[i]     <= 4'd15;
                    xs_done[i] <= 1'b1;
                  end
                  else begin
                    x_s[i] <= x_s[i] + 1'b1;
                  end
                end
              end
            end

            // -----------------------------
            // q_pipe tinh Q52
            // -----------------------------
            if (qcalc_run && !qcalc_done_round) begin
              if (t_round > 0) begin
                if (x_p == 4'd15) begin
                  x_p              <= 4'd15;
                  qcalc_run        <= 1'b0;
                  qcalc_done_round <= 1'b1;
                end
                else begin
                  x_p <= x_p + 1'b1;
                end
              end
            end

            // -----------------------------
            // sang PACK
            // -----------------------------
            if (round_done_all) begin
              state     <= ST_PACK;
              pack_done <= 1'b0;
              pack_cnt  <= 4'd0;
            end
          end

          // =========================================
          // stage gom S của ca round
          //
          // =========================================
          ST_PACK: begin

            // moi clock pack + ghi 1 word S mem
            if (!pack_done) begin
              if (pack_cnt == 4'd15) begin
                pack_done <= 1'b1;
              end
              else begin
                pack_cnt <= pack_cnt + 1'b1;
              end
            end
            else begin

              if (y_round == 3'd4) begin
                state <= ST_DONE;
              end
              else begin
                // sang round moi
                state            <= ST_RUN;
                t_round          <= '0;
                y_round          <= y_round + 1'b1;

                qcalc_run        <= 1'b1;
                qcalc_done_round <= 1'b0;
                x_p              <= 4'd0;
                y_p              <= y_round + 1'b1;

                pack_done        <= 1'b0;
                pack_cnt         <= '0;

                for (i = 0; i < 16; i = i + 1) begin
                  x[i]      <= 4'd0;
                  x_q[i]    <= 4'd0;
                  x_s[i]    <= 4'd0;

                  y[i]      <= y_round + 1'b1;

                  x_done[i]  <= 1'b0;
                  xq_done[i] <= 1'b0;
                  xs_done[i] <= 1'b0;
                end
              end
            end
          end

          // =========================================
          // done 5 round y=0..4
          // =========================================
          ST_DONE: begin
            state            <= ST_IDLE;
            t_round          <= '0;
            y_round          <= '0;

            qcalc_run        <= 1'b0;
            qcalc_done_round <= 1'b0;

            x_p              <= '0;
            y_p              <= '0;
            x_p_d1           <= '0;
            x_p_d2           <= '0;

            pack_done        <= 1'b0;
            pack_cnt         <= '0;

            for (i = 0; i < 16; i = i + 1) begin
                x[i]      <= '0;
                y[i]      <= '0;
                x_q[i]    <= '0;
                x_s[i]    <= '0;

                x_done[i]  <= 1'b0;
                xq_done[i] <= 1'b0;
                xs_done[i] <= 1'b0;
            end
          end
          
          default: begin
            state <= ST_IDLE;
          end

        endcase
      end
    end
  end

  // =========================================================
  // Q pipe
  // =========================================================
  q_pipe U_Q_PIPE (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (q_in_valid),
    .A_mod_uk (A52_p),
    .Bi       (B52_p),
    .S_lo     (S52_p),
    .q_we     (q_we_pipe),
    .Q52      (q52_pipe),
    .Q_lo     (qlo_pipe),
    .Q_hi     (qhi_pipe)
  );

  // =========================================================
  // debug
  // =========================================================
  /*genvar g;
  generate
    for (g = 0; g < 16; g = g + 1) begin : GEN_DBG
      always_comb begin
        x_dbg[g]  = x[g];
        y_dbg[g]  = y[g];
        xq_dbg[g] = x_q[g];
        yq_dbg[g] = y_q[g];
        xs_dbg[g] = x_s[g];
        ys_dbg[g] = y_s[g];
      end
    end
  endgenerate

  always_comb begin
    xp_dbg = x_p;
    yp_dbg = y_p;
  end*/

  //GEN DSP

  genvar g_dsp;
  generate
    for (g_dsp = 0; g_dsp < 16; g_dsp = g_dsp + 1) begin : GEN_DSP_AB_LO
      dsp_wrapper U_DSP_AB (
        .clk       (clk),
        .rst_n     (rst_n),
        .PCIN_in   ((g_dsp == 0) ? 48'd0 : pcout_ab_lo[g_dsp-1]),
        .A_in      ({1'b0, B_lo[g_dsp]}),
        .B_in      ({1'b0, Aseg[g_dsp]}),
        .C_in      ({31'd0, Sseg[g_dsp]}),
        .P_out     (p_ab_lo[g_dsp]),
        .PCOUT_out (pcout_ab_lo[g_dsp])
      );
    end
  endgenerate

  generate
    for (g_dsp = 0; g_dsp < 16; g_dsp = g_dsp + 1) begin : GEN_DSP_AB_HI
      dsp_wrapper U_DSP_AB (
        .clk       (clk),
        .rst_n     (rst_n),
        .PCIN_in   ((g_dsp == 0) ? 48'd0 : pcout_ab_hi[g_dsp-1]),
        .A_in      ({1'b0, B_hi[g_dsp]}),
        .B_in      ({1'b0, Aseg[g_dsp]}),
        .C_in      (48'd0),
        .P_out     (p_ab_hi[g_dsp]),
        .PCOUT_out (pcout_ab_hi[g_dsp])
      );
    end
  endgenerate

  generate
    for (g_dsp = 0; g_dsp < 16; g_dsp = g_dsp + 1) begin : GEN_DSP_NQ_LO
      dsp_wrapper U_DSP_NQ (
        .clk       (clk),
        .rst_n     (rst_n),
        .PCIN_in   ((g_dsp == 0) ? 48'd0 : pcout_nq_lo[g_dsp-1]),
        .A_in      ({1'b0, Q_lo[g_dsp]}),
        .B_in      ({1'b0, Nseg[g_dsp]}),
        .C_in      ((g_dsp == 15) ? p_ab_lo[g_dsp][46:0] : {31'd0, p_ab_lo[g_dsp][16:0]}),
        .P_out     (p_nq_lo[g_dsp]),
        .PCOUT_out (pcout_nq_lo[g_dsp])
      );
    end
  endgenerate
  
  generate
    for (g_dsp = 0; g_dsp < 16; g_dsp = g_dsp + 1) begin : GEN_DSP_NQ_HI
      dsp_wrapper U_DSP_NQ (
        .clk       (clk),
        .rst_n     (rst_n),
        .PCIN_in   ((g_dsp == 0) ? 48'd0 : pcout_nq_hi[g_dsp-1]),
        .A_in      ({1'b0, Q_hi[g_dsp]}),
        .B_in      ({1'b0, Nseg[g_dsp]}),
        .C_in      ((g_dsp == 15) ? p_ab_hi[g_dsp][46:0] : {31'd0, p_ab_hi[g_dsp][16:0]}),
        .P_out     (p_nq_hi[g_dsp]),
        .PCOUT_out (pcout_nq_hi[g_dsp])
      );
    end
  endgenerate

  // =========================================================
  // MEM
  // =========================================================
  mult_mem #(.DEPTH(DEPTH)) U_MEM (
    .clk      (clk),
    .rst_n    (rst_n),

    .start    (start),
    .busy     (busy),
    .mem_valid(mem_valid),
    .batch_done(batch_done),

    .A_in     (A_in),
    .B_in     (B_in),
    .S_in     (S_in),
    .N_in     (N_in),

    .x        (x),
    .y        (y),

    .x_p      (x_p),
    .y_p      (y_p),

    .x_q      (x_q),
    .x_s      (x_s),
    .p_nq_lo_in (p_nq_lo),
    .p_nq_hi_in (p_nq_hi),
    .p_nq_we    (p_nq_we),

    .q_we     (q_we_pipe),
    .q_x      (x_p_d2),
    .q52_in   (q52_pipe),
    .qlo_in   (qlo_pipe),
    .qhi_in   (qhi_pipe),
    
    .s_pack_we (s_pack_we),
    .s_pack_x  (s_pack_x),
    .s256_in   (s256_in_pack),

    .Aseg_o   (Aseg),
    .Sseg_o   (Sseg),
    .B_lo_o   (B_lo),
    .B_hi_o   (B_hi),

    .A52_p    (A52_p),
    .B52_p    (B52_p),
    .S52_p    (S52_p),
    .S_pack_lo_o       (S_pack_lo),
    .S_pack_hi_o       (S_pack_hi),
    .S_pack_lo_valid_o (S_pack_lo_valid),
    .S_pack_hi_valid_o (S_pack_hi_valid),

    .Nseg_q_o (Nseg),
    .Q52_q_o  (Q52),
    .Q_lo_q_o (Q_lo),
    .Q_hi_q_o (Q_hi)
  );

endmodule
