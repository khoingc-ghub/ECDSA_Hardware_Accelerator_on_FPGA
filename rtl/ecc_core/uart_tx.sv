`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2026 06:29:58 PM
// Design Name: 
// Module Name: uart_tx
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



module uart_tx #(
    parameter int CLKS_PER_BIT = 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic tx_dv_i,
    input  logic [7:0] tx_byte_i,

    output logic tx_active_o,
    output logic tx_done_o,
    output logic tx_o
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP,
        S_CLEANUP
    } state_t;

    state_t state;

    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  tx_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            clk_cnt     <= '0;
            bit_idx     <= '0;
            tx_shift    <= '0;
            tx_o        <= 1'b1;
            tx_done_o   <= 1'b0;
            tx_active_o <= 1'b0;
        end else begin
            tx_done_o <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx_o        <= 1'b1;
                    tx_active_o <= 1'b0;
                    clk_cnt     <= '0;
                    bit_idx     <= '0;

                    if (tx_dv_i) begin
                        tx_shift    <= tx_byte_i;
                        tx_active_o <= 1'b1;
                        state       <= S_START;
                    end
                end

                S_START: begin
                    tx_o <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= '0;
                        state   <= S_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    tx_o <= tx_shift[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= '0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= '0;
                            state   <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    tx_o <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= '0;
                        state   <= S_CLEANUP;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_CLEANUP: begin
                    tx_done_o   <= 1'b1;
                    tx_active_o <= 1'b0;
                    state       <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
