`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2026 05:51:32 PM
// Design Name: 
// Module Name: inv_wrapper
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

module inv_wrapper (
    input  logic         clk_i,
    input  logic         rst_ni,

    input  logic         start_i,

    input  logic [255:0] a_i,
    input  logic [255:0] p_i,
    input  logic [255:0] M_i,

    output logic         busy_o,
    output logic         done_o,
    output logic [255:0] r_o
);

    logic         inv_start;
    logic         inv_done;
    logic [255:0] inv_r;

    logic [255:0] a_r;
    logic [255:0] p_r;
    logic [255:0] M_r;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_WAIT,
        ST_DONE
    } state_e;

    state_e state_q;

    //=====//
    // inv //
    //=====//
    inv #(
        .N(256)
    ) U_INV (
        .clk   (clk_i),
        .reset (rst_ni),
        .start (inv_start),
        .a     (a_r),
        .p     (p_r),
        .M     (M_r),
        .r     (inv_r),
        .done  (inv_done)
    );

    //=====//
    // fsm //
    //=====//
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q   <= ST_IDLE;
            inv_start <= 1'b0;
            busy_o    <= 1'b0;
            done_o    <= 1'b0;
            r_o       <= '0;
            a_r       <= '0;
            p_r       <= '0;
            M_r       <= '0;
        end
        else begin
            inv_start <= 1'b0;
            done_o    <= 1'b0;

            case (state_q)
                ST_IDLE: begin
                    busy_o <= 1'b0;

                    if (start_i) begin
                        busy_o    <= 1'b1;

                        a_r       <= a_i;
                        p_r       <= p_i;
                        M_r       <= M_i;

                        inv_start <= 1'b1;
                        state_q   <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (inv_done) begin
                        r_o     <= inv_r;
                        state_q <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    busy_o  <= 1'b0;
                    done_o  <= 1'b1;
                    state_q <= ST_IDLE;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
