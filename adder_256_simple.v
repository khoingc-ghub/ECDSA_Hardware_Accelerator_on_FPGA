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

module adder_256_simple (
    input  [255:0] A, B,   // Toan hang 256-bit
    input          SUB,    // Tin hieu chon cong/tru
    output [255:0] S,       // Tong hoac hieu 256-bit
    output 	   c_out
);
    wire [15:0] fg, fp;    // Generate vs propagate tu GPS/GPSc
    wire [16:1] fpc, spc;  // Carry tu PPN cho GPS v  GPSc
    wire [15:0] fs [15:0]; // Tong cac bien tu GPS/GPSc
    wire [255:0] B_selected; // B hoac ~B

    // Mux cho B: chon B hoac ~B dua tren SUB
    assign B_selected = SUB ? ~B : B;

    // Khoi tao 16 module (GPS toi i=0, GPS toi i=1 ??n 15)
    genvar i;
    generate
        gps_gpsc #(
            .W(16)
        ) gps_inst_0 (
            .a(A[15:0]),
            .b(B_selected[15:0]),
            .cin(SUB), // cin = 0 cho GPS
            .s(fs[0]),
            .g(fg[0]),
            .p(fp[0])
        );

        // Module GPS cho cac khoi i=1 den 15
        for (i = 1; i < 16; i = i + 1) begin: gps_loop
            gps_gpsc #(
                .W(16)
            ) gps_inst (
                .a(A[16*i+15:16*i]),
                .b(B_selected[16*i+15:16*i]),
                .cin(1'b0), // GPS kh ng c  carry-in
                .s(fs[i]),
                .g(fg[i]),
                .p(fp[i])
            );
        end

        // Module GPSc cho tat ca cac khoi i=0 den 15
    endgenerate

    // Mang PPN cho GPS (fg, fp), Ci = 0
    bka16_ppn ppn_gps (
        .G(fg),
        .P(fp),
        .C(fpc)
    );

    // dieu chinh tong bang carry cho SUB = 0  SUB = 1
    wire [15:0] final_sum [15:0];
    generate
        for (i = 0; i < 16; i = i + 1) begin: final_sum_loop
            if (i == 0) begin
                assign final_sum[i] = fs[i]; // Block 0 khong co carry-in
            end else begin
                assign final_sum[i] = fs[i] + fpc[i]; // Cong carry
            end
        end
    endgenerate

    // Gop cac tong cuc bo thanh tong/hieu 256-bit
    assign S = {final_sum[15], final_sum[14], final_sum[13], final_sum[12],
                final_sum[11], final_sum[10], final_sum[9], final_sum[8],
                final_sum[7], final_sum[6], final_sum[5], final_sum[4],
                final_sum[3], final_sum[2], final_sum[1], final_sum[0]};
    //c_out
    assign c_out = fpc[16];
endmodule


