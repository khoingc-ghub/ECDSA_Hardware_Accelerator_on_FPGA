`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 11:31:14 PM
// Design Name: 
// Module Name: addsub_256
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


module gps_gpsc #(
    parameter W = 16
) (
    input  wire [W-1:0] a,    // Toan hang dau tien
    input  wire [W-1:0] b,    // Toan hang thu hai
    input  wire         cin,  // Carry-in
    output wire [W-1:0] s,    // Tong
    output wire         g,    // Generate
    output wire         p     // Propagate
);
    wire [W-1:0] sum_int;
    wire         carry_out;

    assign {carry_out, sum_int} = a + b + cin;
    assign s = sum_int;
    assign g = carry_out;
    assign p = &sum_int;
endmodule

module bka16_ppn (
    input  [15:0] G, P,    // 16 tin hieu g v  p
    output [16:1] C        // Cac carry
);
    wire [7:0] G2, P2;     // Cap 2: 8 bit
    wire [3:0] G3, P3;     // Cap 3: 4 bit
    wire [1:0] G4, P4;     // Cap 4: 2 bit
    wire       G5, P5;     // Cap 5: 1 bit

    // Generating 2nd order P's and G's signals
    genvar i;
    generate
        for (i = 0; i <= 14; i = i + 2) begin: second_stage
            assign G2[i/2] = G[i+1] | (P[i+1] & G[i]);
            assign P2[i/2] = P[i+1] & P[i];
        end
    endgenerate

    // Generating 3rd order P's and G's signals
    generate
        for (i = 0; i <= 6; i = i + 2) begin: third_stage
            assign G3[i/2] = G2[i+1] | (P2[i+1] & G2[i]);
            assign P3[i/2] = P2[i+1] & P2[i];
        end
    endgenerate

    // Generating 4th order P's and G's signals
    generate
        for (i = 0; i <= 2; i = i + 2) begin: fourth_stage
            assign G4[i/2] = G3[i+1] | (P3[i+1] & G3[i]);
            assign P4[i/2] = P3[i+1] & P3[i];
        end
    endgenerate

    // Generating 5th order P's and G's signals
    assign G5 = G4[1] | (P4[1] & G4[0]);
    assign P5 = P4[1] & P4[0];

    // Generating carry signals with Ci = 0
    assign C[1] = G[0];
    assign C[2] = G2[0];
    assign C[4] = G3[0];
    assign C[8] = G4[0];
    assign C[16] = G5;

    assign C[3] = G[2] | (P[2] & C[2]);
    assign C[5] = G[4] | (P[4] & C[4]);
    assign C[6] = G2[2] | (P2[2] & C[4]);
    assign C[7] = G[6] | (P[6] & C[6]);
    assign C[9] = G[8] | (P[8] & C[8]);
    assign C[10] = G2[4] | (P2[4] & C[8]);
    assign C[11] = G[10] | (P[10] & C[10]);
    assign C[12] = G3[2] | (P3[2] & C[8]);
    assign C[13] = G[12] | (P[12] & C[12]);
    assign C[14] = G2[6] | (P2[6] & C[12]);
    assign C[15] = G[14] | (P[14] & C[14]);
endmodule

module addsub_256 (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         start,

    input  logic [255:0] A,
    input  logic [255:0] B,
    input  logic [255:0] P,
    input  logic [255:0] IP,
    input  logic         SUB,

    output logic [255:0] S,
    output logic         done
);

    // =====================================================
    // valid pipeline
    // Giữ giống code cũ:
    // start -> v1 -> v2 -> done
    // S được chốt cùng chu kỳ done.
    // Không bật v3 để khỏi lệch add_tag2 bên ecpa.
    // =====================================================
    logic v1, v2, v3;

    // =====================================================
    // Stage 1 regs
    // =====================================================
    logic [15:0] fs_s1 [0:15];
    logic [15:0] fg_s1;
    logic [15:0] fp_s1;
    logic [255:0] IP_s1;
    logic         SUB_s1;

    // =====================================================
    // Stage 2 regs
    // =====================================================
    logic [15:0] fs_s2 [0:15];
    logic [15:0] ss_s2 [0:15];
    logic [16:1] fpc_s2;
    logic [15:0] sg_s2;
    logic [15:0] sp_s2;
    logic        SUB_s2;

    // =====================================================
    // Stage 1 comb
    // =====================================================
    logic [255:0] B_selected;
    logic [255:0] IP_selected;

    logic [15:0] fs_c [0:15];
    logic [15:0] fg_c;
    logic [15:0] fp_c;

    assign B_selected  = SUB ? ~B : B;
    assign IP_selected = SUB ? P  : IP;

    genvar i;

    generate
        gps_gpsc #(.W(16)) gps_inst_0 (
            .a   (A[15:0]),
            .b   (B_selected[15:0]),
            .cin (SUB),
            .s   (fs_c[0]),
            .g   (fg_c[0]),
            .p   (fp_c[0])
        );

        for (i = 1; i < 16; i = i + 1) begin : GPS_STAGE1
            gps_gpsc #(.W(16)) gps_inst (
                .a   (A[16*i+15 : 16*i]),
                .b   (B_selected[16*i+15 : 16*i]),
                .cin (1'b0),
                .s   (fs_c[i]),
                .g   (fg_c[i]),
                .p   (fp_c[i])
            );
        end
    endgenerate

    // =====================================================
    // Stage 2 comb
    // =====================================================
    logic [15:0] ss_c [0:15];
    logic [15:0] sg_c;
    logic [15:0] sp_c;
    logic [16:1] fpc_c;

    // fs_norm_c là điểm sửa chính:
    // raw result word đúng = fs_s1[i] + carry đầy đủ fpc_c[i]
    logic [15:0] fs_norm_c [0:15];

    bka16_ppn ppn_gps (
        .G (fg_s1),
        .P (fp_s1),
        .C (fpc_c)
    );

    generate
        for (i = 0; i < 16; i = i + 1) begin : FS_NORMALIZE
            if (i == 0) begin
                assign fs_norm_c[i] = fs_s1[i];
            end
            else begin
                assign fs_norm_c[i] = fs_s1[i] + {15'd0, fpc_c[i]};
            end
        end
    endgenerate

    generate
        for (i = 0; i < 16; i = i + 1) begin : GPSC_STAGE2
            gps_gpsc #(.W(16)) gpsc_inst (
                .a   (fs_norm_c[i]),
                .b   (IP_s1[16*i+15 : 16*i]),
                .cin (1'b0),
                .s   (ss_c[i]),
                .g   (sg_c[i]),
                .p   (sp_c[i])
            );
        end
    endgenerate

    // =====================================================
    // Stage 3 comb
    // =====================================================
    logic [16:1] spc_c;
    logic        sel_c;
    logic [15:0] final_sum_c [0:15];

    bka16_ppn ppn_gpsc (
        .G (sg_s2),
        .P (sp_s2),
        .C (spc_c)
    );

    // ADD:
    //   sel = 1 nếu A+B >= P
    // SUB:
    //   sel = 1 nếu A-B bị borrow, tức fpc_s2[16] = 0
    assign sel_c = SUB_s2 ? ~fpc_s2[16] : (fpc_s2[16] | spc_c[16]);

    generate
        for (i = 0; i < 16; i = i + 1) begin : FINAL_SUM_STAGE3
            if (i == 0) begin
                assign final_sum_c[i] = sel_c ? ss_s2[i] : fs_s2[i];
            end
            else begin
                assign final_sum_c[i] = sel_c ?
                                        (ss_s2[i] + {15'd0, spc_c[i]}) :
                                        (fs_s2[i] + {15'd0, fpc_s2[i]});
            end
        end
    endgenerate

    // =====================================================
    // Pipeline registers
    // =====================================================
    integer k;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1   <= 1'b0;
            v2   <= 1'b0;
            v3   <= 1'b0;
            done <= 1'b0;

            IP_s1  <= '0;
            SUB_s1 <= 1'b0;
            SUB_s2 <= 1'b0;

            fg_s1  <= '0;
            fp_s1  <= '0;
            fpc_s2 <= '0;
            sg_s2  <= '0;
            sp_s2  <= '0;

            S <= '0;

            for (k = 0; k < 16; k = k + 1) begin
                fs_s1[k] <= '0;
                fs_s2[k] <= '0;
                ss_s2[k] <= '0;
            end
        end
        else begin
            // --------------------------
            // Valid shift
            // --------------------------
            v1   <= start;
            v2   <= v1;
            v3   <= v2;

            // Giữ giống bản cũ để ecpa dùng add_tag2 không lệch
            done <= v2;

            // --------------------------
            // Stage 1 register
            // --------------------------
            if (start) begin
                IP_s1  <= IP_selected;
                SUB_s1 <= SUB;

                fg_s1 <= fg_c;
                fp_s1 <= fp_c;

                for (k = 0; k < 16; k = k + 1) begin
                    fs_s1[k] <= fs_c[k];
                end
            end

            // --------------------------
            // Stage 2 register
            // --------------------------
            if (v1) begin
                SUB_s2 <= SUB_s1;

                fpc_s2 <= fpc_c[16:1];
                sg_s2  <= sg_c;
                sp_s2  <= sp_c;

                for (k = 0; k < 16; k = k + 1) begin
                    fs_s2[k] <= fs_s1[k];
                    ss_s2[k] <= ss_c[k];
                end
            end

            // --------------------------
            // Stage 3 output register
            // --------------------------
            if (v2) begin
                S <= {
                    final_sum_c[15], final_sum_c[14], final_sum_c[13], final_sum_c[12],
                    final_sum_c[11], final_sum_c[10], final_sum_c[9],  final_sum_c[8],
                    final_sum_c[7],  final_sum_c[6],  final_sum_c[5],  final_sum_c[4],
                    final_sum_c[3],  final_sum_c[2],  final_sum_c[1],  final_sum_c[0]
                };
            end
        end
    end

endmodule
