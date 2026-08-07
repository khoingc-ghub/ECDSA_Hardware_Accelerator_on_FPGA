/*module inv #(
    parameter N = 256 // Bit-width of inputs
) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [N-1:0] a, // Input a ∈ [1, p-1], unsigned
    input wire [N-1:0] p, // Prime modulus p, unsigned
    input wire [N-1:0] M, // Adjustor M, unsigned
    output reg [N-1:0] r, // Output r = a^(-1) * M mod p, unsigned
    output reg done,
    output reg busy
);
    // Internal registers
    reg signed [N+2:0] u, v, r_reg, s;
    reg [9:0] k; // k counts to 2N=512, needs 10 bits
    reg [1:0] state;
    reg [1:0] A_uv_sign, B_uv_sign, A_rs_sign, B_rs_sign, A_sigma_sign, B_sigma_sign;

    // Condition flags
    wire pi0, pi1, pi_bar1, pi2, pi3, pi4, pi5, pi6, pi7, pi8;
    wire [N+2:0] p_258 = {3'b000, p};
    
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
    addsub_256_0mod adder_delta_uv (
        .A(A_uv),
        .B(B_uv),
        .SUB(1'b1),
        .S(delta_uv_raw),
        .c_out(borrow_uv)
    );
    
    addsub_256_0mod adder_delta_rs (
        .A(A_rs),
        .B(B_rs),
        .SUB(1'b1),
        .S(delta_rs_raw),
        .c_out(borrow_rs)
    );
    
    addsub_256_0mod adder_sigma_shared (
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
    reg signed [N+2:0] u_next, v_next, r_next, s_next;
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
            r_next = r_reg; 						// r = r - p
            A_sigma = delta_rs_ext[N-1:0]; 	B_sigma = s[N-1:0];		// sigma = (r - p) + s
	    A_sigma_sign = delta_rs_ext[N+1:N]; B_sigma_sign = s[N+1:N];
            u_next = delta_uv_ext >>> 1; 					// (u-v)/2
            s_next = (s[0] == 0) ? (s >>> 1) : (s >>> 1);
        end

        // Case [pi_bar1 and pi8]: v = 0, r <= p
        else if (pi8) begin
            A_uv = u[N-1:0]; 			
            B_uv = v[N-1:0];		// delta_uv = u - v
	        A_uv_sign = u[N+1:N]; 		
	        B_uv_sign = v[N+1:N];
            A_rs = r_reg[N-1:0]; 		
            B_rs = s[N-1:0];		// delta_rs = r - s
	        A_rs_sign = r_reg[N+1:N]; 		
	        B_rs_sign = s[N+1:N];
            r_next = delta_rs_ext;						// r_reg is already valid
	        A_sigma = r_reg[N-1:0];//delta_rs_ext[N-1:0]; 	
	        B_sigma = s[N-1:0];		// sigma = r - s
	        A_sigma_sign = r_reg[N+1:N];//delta_rs_ext[N+1:N]; 
	        B_sigma_sign = s[N+1:N];           						
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
            busy <= 0;
        end else begin
            done <= 0;
    
            case (state)
                IDLE: begin
                    busy <= 0;
    
                    if (start) begin
                        state <= COMPUTE;
                        u <= {3'b000, p};
                        v <= {3'b000, a};
                        r_reg <= 0;
                        s <= {3'b000, M};
                        k <= 0;
                        r <= 0;
                        done <= 0;
                        busy <= 1;
                    end
                end
    
                COMPUTE: begin
                    busy <= 1;
    
                    if (pi0) begin
                        u <= u_next;
                        v <= v_next;
                        r_reg <= r_next;
                        s <= s_next;
                        k <= k + 1;
                    end else begin
                        state <= DONE;
                        r <= r_reg[255:0];
                        done <= 1;
                        busy <= 0;
                    end
                end
    
                DONE: begin
                    busy <= 0;
                    done <= 0;
                    state <= IDLE;
                end
    
                default: begin
                    state <= IDLE;
                    busy <= 0;
                    done <= 0;
                end
            endcase
        end
    end
endmodule*/
/*module inv #(
    parameter N = 256
) (
    input  wire         clk,
    input  wire         reset,
    input  wire         start,

    input  wire [N-1:0] a,
    input  wire [N-1:0] p,
    input  wire [N-1:0] M,

    output reg  [N-1:0] r,
    output reg          done,
    output reg          busy
);

    localparam IDLE    = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE_S  = 2'd2;

    reg [1:0] state;

    reg signed [N+2:0] u;
    reg signed [N+2:0] v;
    reg signed [N+2:0] r_reg;
    reg signed [N+2:0] s;

    reg [9:0] k;

    wire signed [N+2:0] p_ext;
    assign p_ext = $signed({3'b000, p});

    wire pi0;
    wire pi1;
    wire pi_bar1;
    wire pi2;
    wire pi3;
    wire pi4;
    wire pi5;
    wire pi6;
    wire pi7;
    wire pi8;

    assign pi0     = (k < (2 * N));
    assign pi1     = (v > 0);
    assign pi_bar1 = (v == 0);

    assign pi2 = (u[0] == 1'b0);
    assign pi3 = (~pi2) && (v[0] == 1'b0);
    assign pi4 = (~pi2) && (~pi3) && (u > v);
    assign pi5 = (~pi2) && (~pi3) && (~pi4);

    assign pi6 = pi_bar1 && (r_reg < 0);
    assign pi7 = pi_bar1 && (~pi6) && (r_reg > p_ext);
    assign pi8 = pi_bar1 && (~pi6) && (~pi7);

    reg signed [N+2:0] u_next;
    reg signed [N+2:0] v_next;
    reg signed [N+2:0] r_next;
    reg signed [N+2:0] s_next;

    reg signed [N+2:0] delta_uv;
    reg signed [N+2:0] delta_rs;
    reg signed [N+2:0] sigma;

    //=====================//
    // Algorithm 6 datapath //
    //=====================//
    always @(*) begin
        u_next = u;
        v_next = v;
        r_next = r_reg;
        s_next = s;

        delta_uv = '0;
        delta_rs = '0;
        sigma    = '0;

        if (pi1 && pi2) begin
            delta_uv = u - v;
            delta_rs = r_reg - s;
            sigma    = r_reg + p_ext;

            u_next = u >>> 1;

            if (r_reg[0] == 1'b0) begin
                r_next = r_reg >>> 1;
            end
            else begin
                r_next = sigma >>> 1;
            end
        end

        else if (pi1 && pi3) begin
            delta_uv = u - v;
            delta_rs = r_reg - s;
            sigma    = s + p_ext;

            v_next = v >>> 1;

            if (s[0] == 1'b0) begin
                s_next = s >>> 1;
            end
            else begin
                s_next = sigma >>> 1;
            end
        end

        else if (pi1 && pi4) begin
            delta_uv = u - v;
            delta_rs = r_reg - s;
            sigma    = delta_rs + p_ext;

            u_next = delta_uv >>> 1;

            if (delta_rs[0] == 1'b0) begin
                r_next = delta_rs >>> 1;
            end
            else begin
                r_next = sigma >>> 1;
            end
        end

        else if (pi1 && pi5) begin
            delta_uv = v - u;
            delta_rs = s - r_reg;
            sigma    = delta_rs + p_ext;

            v_next = delta_uv >>> 1;

            if (delta_rs[0] == 1'b0) begin
                s_next = delta_rs >>> 1;
            end
            else begin
                s_next = sigma >>> 1;
            end
        end

        else if (pi6) begin
            delta_uv = u - v;
            delta_rs = s - r_reg;
            sigma    = r_reg + p_ext;

            u_next = delta_uv >>> 1;
            r_next = sigma;
            s_next = s >>> 1;
        end

        else if (pi7) begin
            delta_uv = u - v;
            delta_rs = r_reg - p_ext;
            sigma    = r_reg + s;

            u_next = delta_uv >>> 1;
            r_next = delta_rs;
            s_next = s >>> 1;
        end

        else if (pi8) begin
            delta_uv = u - v;
            delta_rs = r_reg - s;
            sigma    = r_reg + s;

            u_next = delta_uv >>> 1;
            r_next =  r_reg;
            s_next = s >>> 1;
        end
    end

    //=====//
    // fsm //
    //=====//
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;

            u     <= '0;
            v     <= '0;
            r_reg <= '0;
            s     <= '0;
            k     <= '0;

            r     <= '0;
            done  <= 1'b0;
            busy  <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        state <= COMPUTE;

                        u     <= $signed({3'b000, p});
                        v     <= $signed({3'b000, a});
                        r_reg <= '0;
                        s     <= $signed({3'b000, M});
                        k     <= '0;

                        r     <= '0;
                        done  <= 1'b0;
                        busy  <= 1'b1;
                    end
                end

                COMPUTE: begin
                    busy <= 1'b1;

                    if (pi0) begin
                        u     <= u_next;
                        v     <= v_next;
                        r_reg <= r_next;
                        s     <= s_next;
                        k     <= k + 1'b1;
                    end
                    else begin
                        state <= DONE_S;

                        r     <= r_reg[N-1:0];
                        done  <= 1'b1;
                        busy  <= 1'b0;
                    end
                end

                DONE_S: begin
                    busy  <= 1'b0;
                    done  <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy  <= 1'b0;
                    done  <= 1'b0;
                end
            endcase
        end
    end

endmodule*/
`timescale 1ns / 1ps

module inv #(
    parameter N = 256
) (
    input  wire         clk,
    input  wire         reset,
    input  wire         start,

    input  wire [N-1:0] a,
    input  wire [N-1:0] p,
    input  wire [N-1:0] M,

    output reg  [N-1:0] r,
    output reg          done,
    output reg          busy
);

    localparam IDLE    = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE_S  = 2'd2;

    reg [1:0] state;

    reg signed [N+2:0] u;
    reg signed [N+2:0] v;
    reg signed [N+2:0] r_reg;
    reg signed [N+2:0] s;

    reg [9:0] k;

    wire signed [N+2:0] p_ext;
    assign p_ext = $signed({3'b000, p});

    wire pi0;
    wire pi1;
    wire pi_bar1;
    wire pi2;
    wire pi3;
    wire pi4;
    wire pi5;
    wire pi6;
    wire pi7;
    wire pi8;

    assign pi0     = (k < (2 * N));
    assign pi1     = (v > 0);
    assign pi_bar1 = (v == 0);

    assign pi2 = (u[0] == 1'b0);
    assign pi3 = (~pi2) && (v[0] == 1'b0);
    assign pi4 = (~pi2) && (~pi3) && (u > v);
    assign pi5 = (~pi2) && (~pi3) && (~pi4);

    assign pi6 = pi_bar1 && (r_reg < 0);
    assign pi7 = pi_bar1 && (~pi6) && (r_reg > p_ext);
    assign pi8 = pi_bar1 && (~pi6) && (~pi7);

    reg signed [N+2:0] u_next;
    reg signed [N+2:0] v_next;
    reg signed [N+2:0] r_next;
    reg signed [N+2:0] s_next;

    //====================//
    // low 256-bit inputs //
    //====================//
    reg [N-1:0] A_uv;
    reg [N-1:0] B_uv;

    reg [N-1:0] A_rs;
    reg [N-1:0] B_rs;

    reg [N-1:0] A_sigma;
    reg [N-1:0] B_sigma;

    //===================//
    // high signed parts //
    //===================//
    reg signed [2:0] A_uv_hi;
    reg signed [2:0] B_uv_hi;

    reg signed [2:0] A_rs_hi;
    reg signed [2:0] B_rs_hi;

    reg signed [2:0] A_sigma_hi;
    reg signed [2:0] B_sigma_hi;

    //===================//
    // addsub low result //
    //===================//
    wire [N-1:0] delta_uv_raw;
    wire [N-1:0] delta_rs_raw;
    wire [N-1:0] sigma_raw;

    wire c_uv;
    wire c_rs;
    wire c_sigma;

    wire borrow_uv;
    wire borrow_rs;
    wire carry_sigma;

    // Với addsub_256_0mod:
    // SUB=1: c_out=1 là không borrow, c_out=0 là có borrow
    assign borrow_uv   = ~c_uv;
    assign borrow_rs   = ~c_rs;
    assign carry_sigma =  c_sigma;

    //==============//
    // low add/sub  //
    //==============//
    addsub_256_0mod U_SUB_UV (
        .A     (A_uv),
        .B     (B_uv),
        .SUB   (1'b1),
        .S     (delta_uv_raw),
        .c_out (c_uv)
    );

    addsub_256_0mod U_SUB_RS (
        .A     (A_rs),
        .B     (B_rs),
        .SUB   (1'b1),
        .S     (delta_rs_raw),
        .c_out (c_rs)
    );

    addsub_256_0mod U_ADD_SIGMA (
        .A     (A_sigma),
        .B     (B_sigma),
        .SUB   (1'b0),
        .S     (sigma_raw),
        .c_out (c_sigma)
    );

    //====================//
    // high signed result //
    //====================//
    wire signed [3:0] A_uv_hi_ext;
    wire signed [3:0] B_uv_hi_ext;
    wire signed [3:0] A_rs_hi_ext;
    wire signed [3:0] B_rs_hi_ext;
    wire signed [3:0] A_sigma_hi_ext;
    wire signed [3:0] B_sigma_hi_ext;

    assign A_uv_hi_ext    = {A_uv_hi[2], A_uv_hi};
    assign B_uv_hi_ext    = {B_uv_hi[2], B_uv_hi};
    assign A_rs_hi_ext    = {A_rs_hi[2], A_rs_hi};
    assign B_rs_hi_ext    = {B_rs_hi[2], B_rs_hi};
    assign A_sigma_hi_ext = {A_sigma_hi[2], A_sigma_hi};
    assign B_sigma_hi_ext = {B_sigma_hi[2], B_sigma_hi};

    wire signed [3:0] delta_uv_hi;
    wire signed [3:0] delta_rs_hi;
    wire signed [3:0] sigma_hi;

    assign delta_uv_hi = A_uv_hi_ext - B_uv_hi_ext - (borrow_uv ? 4'sd1 : 4'sd0);
    assign delta_rs_hi = A_rs_hi_ext - B_rs_hi_ext - (borrow_rs ? 4'sd1 : 4'sd0);
    assign sigma_hi    = A_sigma_hi_ext + B_sigma_hi_ext + (carry_sigma ? 4'sd1 : 4'sd0);

    wire signed [N+2:0] delta_uv_ext;
    wire signed [N+2:0] delta_rs_ext;
    wire signed [N+2:0] sigma_ext;

    assign delta_uv_ext = $signed({delta_uv_hi[2:0], delta_uv_raw});
    assign delta_rs_ext = $signed({delta_rs_hi[2:0], delta_rs_raw});
    assign sigma_ext    = $signed({sigma_hi[2:0], sigma_raw});

    //=====================//
    // Algorithm 6 datapath //
    //=====================//
    always @(*) begin
        u_next = u;
        v_next = v;
        r_next = r_reg;
        s_next = s;

        A_uv       = '0;
        B_uv       = '0;
        A_rs       = '0;
        B_rs       = '0;
        A_sigma    = '0;
        B_sigma    = '0;

        A_uv_hi    = '0;
        B_uv_hi    = '0;
        A_rs_hi    = '0;
        B_rs_hi    = '0;
        A_sigma_hi = '0;
        B_sigma_hi = '0;

        if (pi1 && pi2) begin
            // delta_uv = u - v
            A_uv    = u[N-1:0];
            B_uv    = v[N-1:0];
            A_uv_hi = u[N+2:N];
            B_uv_hi = v[N+2:N];

            // delta_rs = r - s
            A_rs    = r_reg[N-1:0];
            B_rs    = s[N-1:0];
            A_rs_hi = r_reg[N+2:N];
            B_rs_hi = s[N+2:N];

            // sigma = r + p
            A_sigma    = r_reg[N-1:0];
            B_sigma    = p_ext[N-1:0];
            A_sigma_hi = r_reg[N+2:N];
            B_sigma_hi = p_ext[N+2:N];

            u_next = u >>> 1;

            if (r_reg[0] == 1'b0) begin
                r_next = r_reg >>> 1;
            end
            else begin
                r_next = sigma_ext >>> 1;
            end
        end

        else if (pi1 && pi3) begin
            // delta_uv = u - v
            A_uv    = u[N-1:0];
            B_uv    = v[N-1:0];
            A_uv_hi = u[N+2:N];
            B_uv_hi = v[N+2:N];

            // delta_rs = r - s
            A_rs    = r_reg[N-1:0];
            B_rs    = s[N-1:0];
            A_rs_hi = r_reg[N+2:N];
            B_rs_hi = s[N+2:N];

            // sigma = s + p
            A_sigma    = s[N-1:0];
            B_sigma    = p_ext[N-1:0];
            A_sigma_hi = s[N+2:N];
            B_sigma_hi = p_ext[N+2:N];

            v_next = v >>> 1;

            if (s[0] == 1'b0) begin
                s_next = s >>> 1;
            end
            else begin
                s_next = sigma_ext >>> 1;
            end
        end

        else if (pi1 && pi4) begin
            // delta_uv = u - v
            A_uv    = u[N-1:0];
            B_uv    = v[N-1:0];
            A_uv_hi = u[N+2:N];
            B_uv_hi = v[N+2:N];

            // delta_rs = r - s
            A_rs    = r_reg[N-1:0];
            B_rs    = s[N-1:0];
            A_rs_hi = r_reg[N+2:N];
            B_rs_hi = s[N+2:N];

            // sigma = delta_rs + p
            A_sigma    = delta_rs_ext[N-1:0];
            B_sigma    = p_ext[N-1:0];
            A_sigma_hi = delta_rs_ext[N+2:N];
            B_sigma_hi = p_ext[N+2:N];

            u_next = delta_uv_ext >>> 1;

            if (delta_rs_ext[0] == 1'b0) begin
                r_next = delta_rs_ext >>> 1;
            end
            else begin
                r_next = sigma_ext >>> 1;
            end
        end

        else if (pi1 && pi5) begin
            // delta_uv = v - u
            A_uv    = v[N-1:0];
            B_uv    = u[N-1:0];
            A_uv_hi = v[N+2:N];
            B_uv_hi = u[N+2:N];

            // delta_rs = s - r
            A_rs    = s[N-1:0];
            B_rs    = r_reg[N-1:0];
            A_rs_hi = s[N+2:N];
            B_rs_hi = r_reg[N+2:N];

            // sigma = delta_rs + p
            A_sigma    = delta_rs_ext[N-1:0];
            B_sigma    = p_ext[N-1:0];
            A_sigma_hi = delta_rs_ext[N+2:N];
            B_sigma_hi = p_ext[N+2:N];

            v_next = delta_uv_ext >>> 1;

            if (delta_rs_ext[0] == 1'b0) begin
                s_next = delta_rs_ext >>> 1;
            end
            else begin
                s_next = sigma_ext >>> 1;
            end
        end

        else if (pi6) begin
            // delta_uv = u - v
            A_uv    = u[N-1:0];
            B_uv    = v[N-1:0];
            A_uv_hi = u[N+2:N];
            B_uv_hi = v[N+2:N];

            // delta_rs = s - r
            A_rs    = s[N-1:0];
            B_rs    = r_reg[N-1:0];
            A_rs_hi = s[N+2:N];
            B_rs_hi = r_reg[N+2:N];

            // sigma = r + p
            A_sigma    = r_reg[N-1:0];
            B_sigma    = p_ext[N-1:0];
            A_sigma_hi = r_reg[N+2:N];
            B_sigma_hi = p_ext[N+2:N];

            u_next = delta_uv_ext >>> 1;
            r_next = sigma_ext;
            s_next = s >>> 1;
        end

        else if (pi7) begin
            // delta_uv = u - v
            A_uv    = u[N-1:0];
            B_uv    = v[N-1:0];
            A_uv_hi = u[N+2:N];
            B_uv_hi = v[N+2:N];

            // delta_rs = r - p
            A_rs    = r_reg[N-1:0];
            B_rs    = p_ext[N-1:0];
            A_rs_hi = r_reg[N+2:N];
            B_rs_hi = p_ext[N+2:N];

            // sigma = r + s
            A_sigma    = r_reg[N-1:0];
            B_sigma    = s[N-1:0];
            A_sigma_hi = r_reg[N+2:N];
            B_sigma_hi = s[N+2:N];

            u_next = delta_uv_ext >>> 1;
            r_next = delta_rs_ext;
            s_next = s >>> 1;
        end

        else if (pi8) begin
            // delta_uv = u - v
            A_uv    = u[N-1:0];
            B_uv    = v[N-1:0];
            A_uv_hi = u[N+2:N];
            B_uv_hi = v[N+2:N];

            // dummy delta_rs = r - s
            A_rs    = r_reg[N-1:0];
            B_rs    = s[N-1:0];
            A_rs_hi = r_reg[N+2:N];
            B_rs_hi = s[N+2:N];

            // dummy sigma = r + s
            A_sigma    = r_reg[N-1:0];
            B_sigma    = s[N-1:0];
            A_sigma_hi = r_reg[N+2:N];
            B_sigma_hi = s[N+2:N];

            u_next = delta_uv_ext >>> 1;

            // r is already valid
            r_next = r_reg;

            s_next = s >>> 1;
        end
    end

    //=====//
    // fsm //
    //=====//
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;

            u     <= '0;
            v     <= '0;
            r_reg <= '0;
            s     <= '0;
            k     <= '0;

            r     <= '0;
            done  <= 1'b0;
            busy  <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        state <= COMPUTE;

                        u     <= $signed({3'b000, p});
                        v     <= $signed({3'b000, a});
                        r_reg <= '0;
                        s     <= $signed({3'b000, M});
                        k     <= '0;

                        r     <= '0;
                        done  <= 1'b0;
                        busy  <= 1'b1;
                    end
                end

                COMPUTE: begin
                    busy <= 1'b1;

                    if (pi0) begin
                        u     <= u_next;
                        v     <= v_next;
                        r_reg <= r_next;
                        s     <= s_next;
                        k     <= k + 1'b1;
                    end
                    else begin
                        state <= DONE_S;

                        r     <= r_reg[N-1:0];

                        done  <= 1'b1;
                        busy  <= 1'b0;
                    end
                end

                DONE_S: begin
                    busy  <= 1'b0;
                    done  <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy  <= 1'b0;
                    done  <= 1'b0;
                end
            endcase
        end
    end

endmodule