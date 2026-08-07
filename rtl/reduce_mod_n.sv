`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/24/2026 03:22:08 PM
// Design Name: 
// Module Name: reduce_mod_n
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

module reduce_mod_n (
    input  logic [255:0] x_i,
    input  logic [255:0] n_i,

    output logic [255:0] r_o
);

    logic [255:0] x_minus_n;
    logic         no_borrow;

    //================//
    // x - n          //
    //================//
    addsub_256_0mod U_SUB_N (
        .A     (x_i),
        .B     (n_i),
        .SUB   (1'b1),
        .S     (x_minus_n),
        .c_out (no_borrow)
    );

    //================//
    // reduce result  //
    //================//
    always_comb begin
        if (no_borrow) begin
            r_o = x_minus_n;
        end
        else begin
            r_o = x_i;
        end
    end

endmodule
