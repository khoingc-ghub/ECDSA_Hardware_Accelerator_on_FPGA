// Brent-Kung Adder module (32-bit)
module brent_kung_adder (
    input wire [31:0] A, B,
    input wire Ci,
    output wire [31:0] S,
    output wire Co
);
    wire [31:0] P1, G1;
    wire [32:1] C;
    wire [15:0] G2, P2;
    wire [7:0] G3, P3;
    wire [3:0] G4, P4;
    wire [1:0] G5, P5;
    wire G6, P6;

    // Generating 1st order P's and G's signals
    assign P1 = A ^ B;
    assign G1 = A & B;

    // Generating 2nd order P's and G's signals
    genvar i;
    generate
        for (i = 0; i <= 30; i = i + 2) 
	begin: second_stage
            assign G2[i/2] = G1[i+1] | (P1[i+1] & G1[i]);
            assign P2[i/2] = P1[i+1] & P1[i];
        end
    endgenerate

    // Generating 3rd order P's and G's signals
    generate
        for (i = 0; i <= 14; i = i + 2) 
	begin: third_stage
            assign G3[i/2] = G2[i+1] | (P2[i+1] & G2[i]);
            assign P3[i/2] = P2[i+1] & P2[i];
        end
    endgenerate

    // Generating 4th order P's and G's signals
    generate
        for (i = 0; i <= 6; i = i + 2) 
	begin: fourth_stage
            assign G4[i/2] = G3[i+1] | (P3[i+1] & G3[i]);
            assign P4[i/2] = P3[i+1] & P3[i];
        end
    endgenerate

    // Generating 5th order P's and G's signals
    generate
        for (i = 0; i <= 2; i = i + 2) 
	begin: fifth_stage
            assign G5[i/2] = G4[i+1] | (P4[i+1] & G4[i]);
            assign P5[i/2] = P4[i+1] & P4[i];
        end
    endgenerate

    // Generating 6th order P's and G's signals
    assign G6 = G5[1] | (P5[1] & G5[0]);
    assign P6 = P5[1] & P5[0];

    // Generating carry signals
    assign C[1] = G1[0] | (P1[0] & Ci);
    assign C[2] = G2[0] | (P2[0] & Ci);
    assign C[4] = G3[0] | (P3[0] & Ci);
    assign C[8] = G4[0] | (P4[0] & Ci);
    assign C[16] = G5[0] | (P5[0] & Ci);
    assign C[32] = G6 | (P6 & Ci);

    // Generating remaining carry signals
    assign C[3] = G1[2] | (P1[2] & C[2]);
    assign C[5] = G1[4] | (P1[4] & C[4]);
    assign C[6] = G2[2] | (P2[2] & C[4]);
    assign C[7] = G1[6] | (P1[6] & C[6]);
    assign C[9] = G1[8] | (P1[8] & C[8]);
    assign C[10] = G2[4] | (P2[4] & C[8]);
    assign C[11] = G1[10] | (P1[10] & C[10]);
    assign C[12] = G3[2] | (P3[2] & C[8]);
    assign C[13] = G1[12] | (P1[12] & C[12]);
    assign C[14] = G2[6] | (P2[6] & C[12]);
    assign C[15] = G1[14] | (P1[14] & C[14]);
    assign C[17] = G1[16] | (P1[16] & C[16]);
    assign C[18] = G2[8] | (P2[8] & C[16]);
    assign C[19] = G1[18] | (P1[18] & C[18]);
    assign C[20] = G3[4] | (P3[4] & C[16]);
    assign C[21] = G1[20] | (P1[20] & C[20]);
    assign C[22] = G2[10] | (P2[10] & C[20]);
    assign C[23] = G1[22] | (P1[22] & C[22]);
    assign C[24] = G4[2] | (P4[2] & C[16]);
    assign C[25] = G1[24] | (P1[24] & C[24]);
    assign C[26] = G2[12] | (P2[12] & C[24]);
    assign C[27] = G1[26] | (P1[26] & C[26]);
    assign C[28] = G3[6] | (P3[6] & C[24]);
    assign C[29] = G1[28] | (P1[28] & C[28]);
    assign C[30] = G2[14] | (P2[14] & C[28]);
    assign C[31] = G1[30] | (P1[30] & C[30]);

    // Calculate sum and carry-out
    assign S = P1 ^ {C[31:1], Ci};
    assign Co = C[32];
endmodule

// Brent-Kung Adder 16-bit
module brent_kung_adder_16 (
    input wire [15:0] A, B,
    input wire Ci,
    output wire [15:0] S,
    output wire Co
);
    wire [15:0] P1, G1;
    wire [16:1] C;
    wire [7:0] G2, P2;
    wire [3:0] G3, P3;
    wire [1:0] G4, P4;
    wire G5, P5;

    // Generating 1st order P's and G's signals
    assign P1 = A ^ B;
    assign G1 = A & B;

    // Generating 2nd order P's and G's signals
    genvar i;
    generate
        for (i = 0; i <= 14; i = i + 2) 
	begin: second_stage
            assign G2[i/2] = G1[i+1] | (P1[i+1] & G1[i]);
            assign P2[i/2] = P1[i+1] & P1[i];
        end
    endgenerate

    // Generating 3rd order P's and G's signals
    generate
        for (i = 0; i <= 6; i = i + 2) 
	begin: third_stage
            assign G3[i/2] = G2[i+1] | (P2[i+1] & G2[i]);
            assign P3[i/2] = P2[i+1] & P2[i];
        end
    endgenerate

    // Generating 4th order P's and G's signals
    generate
        for (i = 0; i <= 2; i = i + 2) 
	begin: fourth_stage
            assign G4[i/2] = G3[i+1] | (P3[i+1] & G3[i]);
            assign P4[i/2] = P3[i+1] & P3[i];
        end
    endgenerate

    // Generating 5th order P's and G's signals
    assign G5 = G4[1] | (P4[1] & G4[0]);
    assign P5 = P4[1] & P4[0];

    // Generating carry signals
    assign C[1] = G1[0] | (P1[0] & Ci);
    assign C[2] = G2[0] | (P2[0] & Ci);
    assign C[4] = G3[0] | (P3[0] & Ci);
    assign C[8] = G4[0] | (P4[0] & Ci);
    assign C[16] = G5 | (P5 & Ci);

    // Generating remaining carry signals
    assign C[3] = G1[2] | (P1[2] & C[2]);
    assign C[5] = G1[4] | (P1[4] & C[4]);
    assign C[6] = G2[2] | (P2[2] & C[4]);
    assign C[7] = G1[6] | (P1[6] & C[6]);
    assign C[9] = G1[8] | (P1[8] & C[8]);
    assign C[10] = G2[4] | (P2[4] & C[8]);
    assign C[11] = G1[10] | (P1[10] & C[10]);
    assign C[12] = G3[2] | (P3[2] & C[8]);
    assign C[13] = G1[12] | (P1[12] & C[12]);
    assign C[14] = G2[6] | (P2[6] & C[12]);
    assign C[15] = G1[14] | (P1[14] & C[14]);

    // Calculate sum and carry-out
    assign S = P1 ^ {C[15:1], Ci};
    assign Co = C[16];
endmodule

//Mult module
module mul16_lut_bk (
    input  wire        clk,
    input  wire        rst,
    input  wire        start, // Kich hoat Stage 1
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [31:0] p,
    output reg         done,
    output reg         stage1_valid
);
    reg [31:0] pp[15:0];
    reg [31:0] sum1[7:0];
    integer i;

    // Stage 0: (combinational)
    always @(*) 
    begin
        for (i = 0; i < 16; i = i + 1) 
	begin
            pp[i] = b[i] ? (a << i) : 32'b0;
        end
    end

    // Stage 1 va 2: Pipeline
    always @(posedge clk or posedge rst) 
    begin
        if (rst) 
	begin
            for (i = 0; i < 8; i = i + 1) 
	    sum1[i] <= 32'b0;
            p <= 32'b0;
            done <= 1'b0;
            stage1_valid <= 1'b0;
        end else begin
            if (start) 
	    begin
                sum1[0] <= pp[0] + pp[1];
                sum1[1] <= pp[2] + pp[3];
                sum1[2] <= pp[4] + pp[5];
                sum1[3] <= pp[6] + pp[7];
                sum1[4] <= pp[8] + pp[9];
                sum1[5] <= pp[10] + pp[11];
                sum1[6] <= pp[12] + pp[13];
                sum1[7] <= pp[14] + pp[15];
                stage1_valid <= 1'b1;
            end else begin
                stage1_valid <= 1'b0;
            end

            // Stage 2: Sum
            if (stage1_valid) 
	    begin
                p <= sum1[0] + sum1[1] + sum1[2] + sum1[3] +
                     sum1[4] + sum1[5] + sum1[6] + sum1[7];
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
endmodule

// Main module
module knuth (
    input wire [31:0] x,
    input wire [31:0] y,
    input wire clk,
    input wire rst,
    input wire start,
    output reg [63:0] result,
    output reg done
);
    // Input registers to hold x, y
    reg [31:0] x_reg, y_reg;

    // Split inputs into 16-bit segments
    wire [15:0] x1 = x_reg[31:16];
    wire [15:0] x0 = x_reg[15:0];
    wire [15:0] y1 = y_reg[31:16];
    wire [15:0] y0 = y_reg[15:0];

    // Pipeline registers for stage 1
    reg [1:0] dsp_step;
    reg [31:0] P0_reg1, P1a_reg1, P1b_reg1, P2_reg1;
    reg stage1_busy, stage1_done;
    reg [1:0] result_count; 
    wire [31:0] mul_result;
    wire mul_done;
    wire stage1_valid;

    // Pipeline registers for stage 2
    reg [31:0] P0_reg2, P1a_reg2, P1b_reg2, P2_reg2;
    reg [31:0] A_reg2, B_reg2, intermediate_reg2;
    reg carry_out_reg2, carry_out_reg3;
    reg [1:0] stage2_state;
    //reg stage2_ready;

    // Wires for adder outputs
    wire [31:0] adder_step1_S, adder_step2_S;
    wire [15:0] adder_final_S;
    wire adder_step1_Co, adder_step2_Co, adder_final_Co;
    	
    // MULT
    mul16_lut_bk multiplier (
        .clk(clk),
        .rst(rst),
        .start(stage1_busy), // Su dung stage1_busy lam start
        .a(dsp_step == 2'd0 ? x0 : 
           dsp_step == 2'd1 ? x1 : 
           dsp_step == 2'd2 ? x0 : x1),
        .b(dsp_step == 2'd0 ? y0 : 
           dsp_step == 2'd1 ? y0 : 
           dsp_step == 2'd2 ? y1 : y1),
        .p(mul_result),
        .done(mul_done),
        .stage1_valid(stage1_valid)
    );

    // Brent-Kung adder instantiations
    brent_kung_adder adder_step1 (
        .A(P1a_reg2),
        .B(P1b_reg2),
        .Ci(1'b0),
        .S(adder_step1_S),
        .Co(adder_step1_Co)
    );

    brent_kung_adder adder_step2 (
        .A(A_reg2),
        .B(B_reg2),
        .Ci(1'b0),
        .S(adder_step2_S),
        .Co(adder_step2_Co)
    );

    brent_kung_adder_16 adder_final (
        .A(P2_reg2[31:16]),
        .B({15'b0, carry_out_reg2}),
        .Ci(carry_out_reg3),
        .S(adder_final_S),
        .Co(adder_final_Co)
    );

    // Stage 1: Compute partial products and store inputs
    always @(posedge clk or posedge rst) 
    begin
        if (rst) 
	begin
            x_reg <= 32'b0;
            y_reg <= 32'b0;
            P0_reg1 <= 32'b0;
            P1a_reg1 <= 32'b0;
            P1b_reg1 <= 32'b0;
            P2_reg1 <= 32'b0;
            stage1_busy <= 1'b0;
            stage1_done <= 1'b0;
            dsp_step <= 2'b00;
            result_count <= 2'b00;
        end else begin
            // Store new x, y when start is high and stage 1 is not busy
            if (start && !stage1_busy) 
	    begin
                x_reg <= x;
                y_reg <= y;
                stage1_busy <= 1'b1;
                dsp_step <= 2'b00;
		result_count <= 2'b00;
            end

	    if (stage1_done && stage2_state != 2'b00) 
	    begin
    		stage1_done <= 1'b0;
	    end

            // Compute partial products
            if (stage1_busy && !stage1_done) 
	    begin
                // dsp+1 w khi stage1_valid bat
                if ((dsp_step == 0 || stage1_valid) && dsp_step < 2'd3) begin
                    dsp_step <= dsp_step + 1;
                end

                if (mul_done) 
  		begin
                    case (result_count)
                        2'd0: P0_reg1 <= mul_result; // x0*y0
                        2'd1: P1a_reg1 <= mul_result; // x1*y0
                        2'd2: P1b_reg1 <= mul_result; // x0*y1
                        2'd3: begin
                            P2_reg1 <= mul_result; // x1*y1
                            stage1_done <= 1'b1;
			    stage1_busy <= 1'b0;
                        end
                    endcase
                    result_count <= result_count + 1;
                end
            end
        end
    end

    // Stage 2: Perform additions
   always @(posedge clk or posedge rst) 
   begin
        if (rst) 
	begin
            P0_reg2 <= 32'b0;
            P1a_reg2 <= 32'b0;
            P1b_reg2 <= 32'b0;
            P2_reg2 <= 32'b0;
            A_reg2 <= 32'b0;
            B_reg2 <= 32'b0;
            intermediate_reg2 <= 32'b0;
            carry_out_reg2 <= 1'b0;
            carry_out_reg3 <= 1'b0;
	    //stage2_ready <= 1'b0;
            stage2_state <= 2'b00;
            result <= 64'b0;
            done <= 1'b0;
        end else begin
            case (stage2_state)
                2'b00: begin // Idle state, waiting for stage1_done
		    if (stage1_done) begin
                        P0_reg2 <= P0_reg1;
                        P1a_reg2 <= P1a_reg1;
                        P1b_reg2 <= P1b_reg1;
                        P2_reg2 <= P2_reg1;
			//stage2_ready <= 1'b1;
                        stage2_state <= 2'b01;
                    end	
                end
                2'b01: begin // Sub-stage 1: P1a + P1b and prepare B_reg2
                    //stage2_ready <= 1'b0;
		    A_reg2 <= adder_step1_S;
                    carry_out_reg2 <= adder_step1_Co;
                    B_reg2 <= {P2_reg2[15:0], P0_reg2[31:16]};
                    stage2_state <= 2'b10;
                end
                2'b10: begin // Sub-stage 2: (P1a + P1b) + (P2[15:0], P0[31:16]) and final addition
		    intermediate_reg2 <= adder_step2_S;
                    carry_out_reg3 <= adder_step2_Co;
                    result <= {adder_final_S, adder_step2_S, P0_reg2[15:0]};
                    done <= 1'b1;
                    stage2_state <= 2'b00; // Return to idle
                end
            endcase

            // Reset done signal
            if (done) 
	    begin
                done <= 1'b0;
            end
        end
    end
endmodule
