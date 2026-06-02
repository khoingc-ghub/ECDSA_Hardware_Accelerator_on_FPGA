`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2026 06:29:15 PM
// Design Name: 
// Module Name: uart_rx
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



module uart_rx #(
    parameter int CLKS_PER_BIT = 868   // 100MHz / 115200 ~ 868
)(
    input  logic clk,
    input  logic rst_n,
    input  logic rx_i,

    output logic rx_dv_o,
    output logic [7:0] rx_byte_o
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
    logic [7:0]  rx_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_cnt   <= '0;
            bit_idx   <= '0;
            rx_shift  <= '0;
            rx_dv_o   <= 1'b0;
            rx_byte_o <= 8'h00;
        end else begin
            rx_dv_o <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_cnt <= '0;
                    bit_idx <= '0;
                    if (rx_i == 1'b0)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_cnt == (CLKS_PER_BIT-1)/2) begin
                        if (rx_i == 1'b0) begin
                            clk_cnt <= '0;
                            state   <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= '0;
                        rx_shift[bit_idx] <= rx_i;

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
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        rx_byte_o <= rx_shift;
                        rx_dv_o   <= 1'b1;
                        clk_cnt   <= '0;
                        state     <= S_CLEANUP;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_CLEANUP: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
