////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Filename : inversion_unit.v                                                //
// Description : This module implements the inversion based on the constant-time binary extended Euclidean algorithm bEEA
//
// Author : khoi.ngo04@hcmut.edu.vn
// Created On : Fri Nov 3 20:29:44 2025
// History (Date, Changed By)
// Sat Nov 4 reduce adder 8 down to 3
// Sat Nov 4 change bug + instead of module adder
// Thur NOV 9 update adder 0 mod p and reduce all redundant variables         //
//            	                                                              //
////////////////////////////////////////////////////////////////////////////////

module mont_inv_alg6 #(
    parameter N = 256 // Bit-width of inputs
) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [N-1:0] a, // Input a ∈ [1, p-1], unsigned
    input wire [N-1:0] p, // Prime modulus p, unsigned
    input wire [N-1:0] M, // Adjustor M, unsigned
    output reg [N-1:0] r, // Output r = a^(-1) * M mod p, unsigned
    output reg done
);
    // Internal registers
    reg signed [N+1:0] u, v, r_reg, s;
    reg [9:0] k; // k counts to 2N=512, needs 10 bits
    reg [1:0] state;
    reg [1:0] A_uv_sign, B_uv_sign, A_rs_sign, B_rs_sign, A_sigma_sign, B_sigma_sign;

    // Condition flags
    wire pi0, pi1, pi_bar1, pi2, pi3, pi4, pi5, pi6, pi7, pi8;
    wire [N+1:0] p_258 = {2'b00, p};
    
    // State encoding
    localparam IDLE = 2'd0,
               COMPUTE = 2'd1,
               DONE = 2'd2;
   
    // Compute condition flags
    assign pi0 = (k < 2 * N); // k < 2N (512 for N=256)
    assign pi1 = (v > 0); // v > 0
    assign pi_bar1 = (v == 0); // v = 0
    assign pi2 = (u[0] == 0); // u is even (LSB check)
    assign pi3 = (~pi2) && (v[0] == 0); // u odd, v even
    assign pi4 = (~pi2) && (~pi3) && (u > v); // u odd, v odd, u > v
    assign pi5 = (~pi2) && (~pi3) && (~pi4); // u odd, v odd, u <= v
     
    // Update pi6 and pi7 based on borrow/carry
    assign pi6 = pi_bar1 && (r_reg < 0); // v = 0, r < 0 or borrow indicates negative
    assign pi7 = pi_bar1 && (~pi6) && (r_reg > p_258); // v = 0, r >= 0, r > p or carry indicates overflow
    assign pi8 = pi_bar1 && (~pi6) && (~pi7); // v = 0, r >= 0, r <= p
    
    // Temporary variables for adder outputs
    wire [N-1:0] delta_uv_raw, delta_rs_raw, sigma_raw;
    wire borrow_uv, borrow_rs, carry_sigma;
    reg [N-1:0] A_uv, B_uv, A_rs, B_rs, A_sigma, B_sigma;
    wire signed [N+1:0] delta_uv_ext, delta_rs_ext, sigma_ext;
    wire [1:0] uv_sign, rs_sign, sigma_sign;

    // Adder instances
    adder_256_simple adder_delta_uv (
        .A(A_uv),
        .B(B_uv),
        .SUB(1'b1),
        .S(delta_uv_raw),
        .c_out(borrow_uv)
    );
    
    adder_256_simple adder_delta_rs (
        .A(A_rs),
        .B(B_rs),
        .SUB(1'b1),
        .S(delta_rs_raw),
        .c_out(borrow_rs)
    );
    
    adder_256_simple adder_sigma_shared (
        .A(A_sigma),
        .B(B_sigma),
        .SUB(1'b0),
        .S(sigma_raw),
        .c_out(carry_sigma)
    );
    
    assign uv_sign =  (A_uv_sign == 2'b11 && B_uv_sign == 2'b11 && (~borrow_uv)) ? 2'b11 :
		      (A_uv_sign == 2'b00 && B_uv_sign == 2'b11 && borrow_uv) ? 2'b01 :
		      (A_uv_sign == 2'b01 && B_uv_sign == 2'b11 && (~borrow_uv)) ? 2'b01 :
		      (A_uv_sign == 2'b11 && B_uv_sign == 2'b00 && borrow_uv) ? 2'b11 :
		      (A_uv_sign == 2'b11 && B_uv_sign == 2'b00 && (~borrow_uv)) ? 2'b01 :
                      (A_uv_sign == 2'b00 && B_uv_sign == 2'b00 && (~borrow_uv)) ? 2'b11 :
                      (A_uv_sign == 2'b00 && B_uv_sign == 2'b01) ? 2'b11 :
                      (A_uv_sign == 2'b01 && B_uv_sign == 2'b01 && (~borrow_uv)) ? 2'b11 :
                      (A_uv_sign == 2'b01 && B_uv_sign == 2'b00 && borrow_uv) ? 2'b01 :
                      2'b00;

    assign rs_sign =  (A_rs_sign == 2'b11 && B_rs_sign == 2'b11 && (~borrow_rs)) ? 2'b11 :
		      (A_rs_sign == 2'b00 && B_rs_sign == 2'b11 && borrow_rs) ? 2'b01 :
		      (A_rs_sign == 2'b01 && B_rs_sign == 2'b11 && (~borrow_rs)) ? 2'b01 :
		      (A_rs_sign == 2'b11 && B_rs_sign == 2'b00 && borrow_rs) ? 2'b11 :
		      (A_rs_sign == 2'b11 && B_rs_sign == 2'b00 && (~borrow_rs)) ? 2'b01 :
                      (A_rs_sign == 2'b00 && B_rs_sign == 2'b00 && (~borrow_rs)) ? 2'b11 :
                      (A_rs_sign == 2'b00 && B_rs_sign == 2'b01) ? 2'b11 :
                      (A_rs_sign == 2'b01 && B_rs_sign == 2'b01 && (~borrow_rs)) ? 2'b11 :
                      (A_rs_sign == 2'b01 && B_rs_sign == 2'b00 && borrow_rs) ? 2'b01 :
                      2'b00;
            
    assign sigma_sign = (A_sigma_sign == 2'b00 && B_sigma_sign == 2'b11) ? (carry_sigma ? 2'b00 : 2'b11) :
    			(A_sigma_sign == 2'b01 && B_sigma_sign == 2'b11) ? (carry_sigma ? 2'b01 : 2'b00) :
    			(A_sigma_sign == 2'b11 && B_sigma_sign == 2'b00) ? (carry_sigma ? 2'b00 : 2'b11) : 
    			(A_sigma_sign == 2'b11 && B_sigma_sign == 2'b01) ? (carry_sigma ? 2'b01 : 2'b00) : 
			(A_sigma_sign == 2'b11 && B_sigma_sign == 2'b11) ? (carry_sigma ? 2'b11 : 2'b00) : 
    			(A_sigma_sign == 2'b00 && B_sigma_sign == 2'b00) ? (carry_sigma ? 2'b01 : 2'b00) : 
			(A_sigma_sign == 2'b00 && B_sigma_sign == 2'b01) ? (carry_sigma ? 2'b00 : 2'b01) :
			(A_sigma_sign == 2'b01 && B_sigma_sign == 2'b00) ? (carry_sigma ? 2'b00 : 2'b01) :
			2'b00;

    assign delta_uv_ext = {uv_sign, delta_uv_raw};
    assign delta_rs_ext = {rs_sign, delta_rs_raw};
    assign sigma_ext = {sigma_sign, sigma_raw};
    
    // Combinational logic for computations
    reg signed [N+1:0] u_next, v_next, r_next, s_next;
    always @(*) begin
        // Default assignments
        u_next = u;
        v_next = v;
        r_next = r_reg;
        s_next = s;
        A_uv = 0;
        B_uv = 0;
	A_uv_sign = 2'b00;
        B_uv_sign = 2'b00;
        A_rs = 0;
        B_rs = 0;
	A_rs_sign = 2'b00;
        B_rs_sign = 2'b00;
        A_sigma = 0;
        B_sigma = 0;
        A_sigma_sign = 2'b00;
        B_sigma_sign = 2'b00;

        if (pi1 && pi2) begin
            A_uv = u[N-1:0]; 			B_uv = v[N-1:0]; 		// delta_uv = u - v
	    A_uv_sign = u[N+1:N]; 		B_uv_sign = v[N+1:N];
            A_rs = r_reg[N-1:0]; 		B_rs = s[N-1:0]; 		// delta_rs = r - s
	    A_rs_sign = r_reg[N+1:N]; 		B_rs_sign = s[N+1:N];
            A_sigma = r_reg[N-1:0]; 		B_sigma = p_258[N-1:0]; 			// sigma = r + p
	    A_sigma_sign = r_reg[N+1:N]; 	B_sigma_sign = p_258[N+1:N];
            u_next = u >>> 1; 							// u/2
            r_next = (r_reg[0] == 0) ? (r_reg >>> 1) : (sigma_ext >>> 1);
        end

        // Case [pi1 and pi3]: u odd, v even
        else if (pi1 && pi3) begin
            A_uv = u[N-1:0]; 			B_uv = v[N-1:0]; 		// delta_uv = u - v
            A_uv_sign = u[N+1:N]; 		B_uv_sign = v[N+1:N];
            A_rs = r_reg[N-1:0]; 		B_rs = s[N-1:0];		// delta_rs = r - s
	    A_rs_sign = r_reg[N+1:N]; 		B_rs_sign = s[N+1:N];
            A_sigma = s[N-1:0]; 		B_sigma = p_258[N-1:0];			// sigma = s + p
	    A_sigma_sign = s[N+1:N]; 		B_sigma_sign = p_258[N+1:N];
            v_next = v >>> 1; 							// v/2
            s_next = (s[0] == 0) ? (s >>> 1) : (sigma_ext >>> 1);
        end

        // Case [pi1 and pi4]: u odd, v odd, u > v
        else if (pi1 && pi4) begin
            A_uv = u[N-1:0]; 			B_uv = v[N-1:0];		// delta_uv = u - v
	    A_uv_sign = u[N+1:N]; 		B_uv_sign = v[N+1:N];
            A_rs = r_reg[N-1:0]; 		B_rs = s[N-1:0];		// delta_rs = r - s
	    A_rs_sign = r_reg[N+1:N]; 		B_rs_sign = s[N+1:N];
            A_sigma = delta_rs_ext[N-1:0]; 	B_sigma = p_258[N-1:0];		// sigma = (r - s) + p
	    A_sigma_sign = delta_rs_ext[N+1:N]; B_sigma_sign = p_258[N+1:N];
            u_next = delta_uv_ext >>> 1; 					// (u-v)/2
            r_next = (delta_rs_ext[0] == 0) ? (delta_rs_ext >>> 1) : (sigma_ext >>> 1);
        end

        // Case [pi1 and pi5]: u odd, v odd, u <= v
        else if (pi1 && pi5) begin
            A_uv = v[N-1:0]; 			B_uv = u[N-1:0];		// delta_uv = v - u
	    A_uv_sign = v[N+1:N]; 		B_uv_sign = u[N+1:N];
            A_rs = s[N-1:0]; 			B_rs = r_reg[N-1:0];		// delta_rs = s - r
	    A_rs_sign = s[N+1:N]; 		B_rs_sign = r_reg[N+1:N];
            A_sigma = delta_rs_ext[N-1:0]; 	B_sigma = p_258[N-1:0];		// sigma = (s - r) + p
	    A_sigma_sign = delta_rs_ext[N+1:N]; B_sigma_sign = p_258[N+1:N];
            v_next = delta_uv_ext >>> 1;	 				// (v-u)/2
            s_next = (delta_rs_ext[0] == 0) ? (delta_rs_ext >>> 1) : (sigma_ext >>> 1);
        end

        // Case [pi_bar1 and pi6]: v = 0, r < 0 (or borrow)
        else if (pi6) begin
            A_uv = u[N-1:0]; 			B_uv = v[N-1:0];		// delta_uv = u - v
	    A_uv_sign = u[N+1:N]; 		B_uv_sign = v[N+1:N];
            A_rs = s[N-1:0]; 			B_rs = r_reg[N-1:0];		// delta_rs = s - r
	    A_rs_sign = s[N+1:N]; 		B_rs_sign = r_reg[N+1:N];
            A_sigma = r_reg[N-1:0]; 		B_sigma = p_258[N-1:0];		// sigma = r + p
	    A_sigma_sign = r_reg[N+1:N]; 	B_sigma_sign = p_258[N+1:N];
            r_next = sigma_ext; 						// r = r + p
            u_next = delta_uv_ext >>> 1; 					// (u-v)/2
            s_next = (s[0] == 0) ? (s >>> 1) : (s >>> 1);
        end

        // Case [pi_bar1 and pi7]: v = 0, r > p
        else if (pi7) begin
            A_uv = u[N-1:0]; 			B_uv = v[N-1:0];		// delta_uv = u - v
	    A_uv_sign = u[N+1:N]; 		B_uv_sign = v[N+1:N];
            A_rs = r_reg[N-1:0]; 		B_rs = p_258[N-1:0];		// delta_rs = r - p
	    A_rs_sign = r_reg[N+1:N]; 		B_rs_sign = p_258[N+1:N];
            r_next = delta_rs_ext; 						// r = r - p
            A_sigma = delta_rs_ext[N-1:0]; 	B_sigma = s[N-1:0];		// sigma = (r - p) + s
	    A_sigma_sign = delta_rs_ext[N+1:N]; B_sigma_sign = s[N+1:N];
            u_next = delta_uv_ext >>> 1; 					// (u-v)/2
            s_next = (s[0] == 0) ? (s >>> 1) : (s >>> 1);
        end

        // Case [pi_bar1 and pi8]: v = 0, r <= p
        else if (pi8) begin
            A_uv = u[N-1:0]; 			B_uv = v[N-1:0];		// delta_uv = u - v
	    A_uv_sign = u[N+1:N]; 		B_uv_sign = v[N+1:N];
            A_rs = r_reg[N-1:0]; 		B_rs = s[N-1:0];		// delta_rs = r - s
	    A_rs_sign = r_reg[N+1:N]; 		B_rs_sign = s[N+1:N];
            r_next = delta_rs_ext;						// r_reg is already valid
	    A_sigma = delta_rs_ext[N-1:0]; 	B_sigma = s[N-1:0];		// sigma = r - s
	    A_sigma_sign = delta_rs_ext[N+1:N]; B_sigma_sign = s[N+1:N];           						
            u_next = delta_uv_ext >>> 1; 					// (u-v)/2
            s_next = (s[0] == 0) ? (s >>> 1) : (s >>> 1);
        end
    end
   
    // Sequential logic
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            u <= 0;
            v <= 0;
            r_reg <= 0;
            s <= 0;
            k <= 0;
            r <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE;
                        u <= {2'b00, p};
                        v <= {2'b00, a};
                        r_reg <= 0;
                        s <= {2'b00, M};
                        k <= 0;
                        done <= 0;
                    end
                end
                COMPUTE: begin
                    if (pi0) begin
                        u <= u_next;
                        v <= v_next;
                        r_reg <= r_next;
                        s <= s_next;
                        k <= k + 1;
                    end else begin
                        state <= DONE;
                        r <= r_next[255:0];
                        done <= 1;
                    end
                end
                DONE: begin
                    done <= 1;
                    if (start) begin
                        state <= COMPUTE;
                        u <= {2'b00, p};
                        v <= {2'b00, a};
                        r_reg <= 0;
                        s <= {2'b00, M};
                        k <= 0;
                        done <= 0;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule