`timescale 1ns / 1ps

module tb_adder_256_modular;
    reg  [255:0] A, B, P;
    reg          SUB;
    wire [255:0] S;

    adder_256 uut (
        .A(A), .B(B), .P(P), .SUB(SUB), .S(S)
    );

    initial begin
        // Test case 1: A + B mod P
        A   = 256'h0000_0000_0000_0000_0000_0000_0000_0001;
        B   = 256'h0000_0000_0000_0000_0000_0000_0000_0002;
        P   = 256'h0000_0000_0000_0000_0000_0000_0000_0005;
        SUB = 1'b0; // C?ng

        #10;
        $display("Test 1: A + B mod P");
        $display("A   = %h", A);
        $display("B   = %h", B);
        $display("P   = %h", P);
        $display("S   = %h", S); // Expected = 3

        // Test case 2: A - B mod P
        A   = 256'h0000_0000_0000_0000_0000_0000_0000_0001;
        B   = 256'h0000_0000_0000_0000_0000_0000_0000_0002;
        P   = 256'h0000_0000_0000_0000_0000_0000_0000_0005;
        SUB = 1'b1; // Tr?

        #10;
        $display("Test 2: A - B mod P");
        $display("A   = %h", A);
        $display("B   = %h", B);
        $display("P   = %h", P);
        $display("S   = %h", S); // Expected = (1 - 2) mod 5 = 4

        #10 $stop;
    end
endmodule

