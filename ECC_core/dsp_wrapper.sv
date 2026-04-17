`timescale 1ns / 1ps

module dsp_wrapper #(
    parameter int PCIN_DELAY = 3   // so clk delay PCIN tuong ung voi reg A/B/C
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic [47:0] PCIN_in,
    input  logic [26:0] A_in,
    input  logic [17:0] B_in,
    input  logic [47:0] C_in,

    output logic [47:0] P_out,
    output logic [47:0] PCOUT_out
    );
    
    // Delay line for PCIN
    logic [47:0] pcin_d [0:(PCIN_DELAY>0 ? PCIN_DELAY-1 : 0)];
    logic [47:0] PCIN_use;

    generate
        if (PCIN_DELAY == 0) begin : NO_DELAY
            always_comb PCIN_use = PCIN_in;
        end else begin : GEN_DELAY
            always_comb PCIN_use = pcin_d[PCIN_DELAY-1];

            integer i;
            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    for (i = 0; i < PCIN_DELAY; i++) begin
                        pcin_d[i] <= 48'd0;
                    end
                end else begin
                    pcin_d[0] <= PCIN_in;
                    for (i = 1; i < PCIN_DELAY; i++) begin
                        pcin_d[i] <= pcin_d[i-1];
                    end
                end
            end
        end
    endgenerate

    // Call DSP macro
    dsp_macro_0 u_dsp (
        .CLK   (clk),
        .PCIN  (PCIN_use),
        .A     (A_in),
        .B     (B_in),
        .C     (C_in),
        .P     (P_out),
        .PCOUT (PCOUT_out)
    );
    
endmodule