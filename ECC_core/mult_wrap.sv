`timescale 1ns / 1ps

module mult_wrap #(
    parameter int DEPTH = 16
)(
    input  logic         clk,
    input  logic         rst_n,

    input  logic         start_stage,
    input  logic [4:0]   op_count,     // 0..16
    input  logic [255:0] N_mod,

    input  logic [255:0] A_vec [DEPTH],
    input  logic [255:0] B_vec [DEPTH],
    input  logic [255:0] S_vec [DEPTH],

    output logic         busy,
    output logic         done,
    output logic [255:0] R_vec [DEPTH]
);

    typedef enum logic [1:0] {
        ST_IDLE = 2'd0,
        ST_LOAD = 2'd1,
        ST_WAIT = 2'd2
    } state_t;

    state_t state;
    logic [4:0] load_idx;

    logic         mult_start;
    logic [255:0] mult_A_in, mult_B_in, mult_S_in, mult_N_in;
    logic         mult_busy;
    logic [255:0] mult_R [DEPTH];
    logic         mult_R_valid;

    integer i;

    // -------------------------------------------------
    // phát input trực tiếp vào mult_top
    // -------------------------------------------------
    always_comb begin
        mult_start = 1'b0;
        mult_A_in  = 256'd0;
        mult_B_in  = 256'd0;
        mult_S_in  = 256'd0;
        mult_N_in  = N_mod;

        if (state == ST_LOAD) begin
            mult_start = 1'b1;
            mult_N_in  = N_mod;

            if (load_idx < op_count) begin
                mult_A_in = A_vec[load_idx];
                mult_B_in = B_vec[load_idx];
                mult_S_in = S_vec[load_idx];
            end
            else begin
                // pad dummy cho đủ 16 slot
                mult_A_in = 256'd0;
                mult_B_in = 256'd0;
                mult_S_in = 256'd0;
            end
        end
    end

    // -------------------------------------------------
    // mult_top giữ nguyên, không sửa logic
    // -------------------------------------------------
    mult_top #(
        .DEPTH(DEPTH)
    ) U_MULT_TOP (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (mult_start),
        .A_in             (mult_A_in),
        .B_in             (mult_B_in),
        .S_in             (mult_S_in),
        .N_in             (mult_N_in),
        .busy             (mult_busy),
        .S_out_final      (mult_R),
        .S_out_final_valid(mult_R_valid)
    );

    // -------------------------------------------------
    // FSM wrapper
    // -------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            load_idx <= '0;
            busy     <= 1'b0;
            done     <= 1'b0;

            for (i = 0; i < DEPTH; i = i + 1)
                R_vec[i] <= '0;
        end
        else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy     <= 1'b0;
                    load_idx <= '0;

                    if (start_stage) begin
                        busy  <= 1'b1;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    // nạp đúng 16 clock, vì DEPTH cố định = 16
                    if (load_idx == DEPTH-1) begin
                        load_idx <= '0;
                        state    <= ST_WAIT;
                    end
                    else begin
                        load_idx <= load_idx + 1'b1;
                    end
                end

                ST_WAIT: begin
                    if (mult_R_valid) begin
                        for (i = 0; i < DEPTH; i = i + 1)
                            R_vec[i] <= mult_R[i];

                        busy <= 1'b0;
                        done <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule