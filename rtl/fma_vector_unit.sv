module fma_vector_unit #(
    parameter int VECTOR_LEN = 16,
    parameter int EXP_BITS   = 4,
    parameter int MAN_BITS   = 3
) (
    input  logic                       clk,
    input  logic                       rst,
    input  logic [1:0]                 fmt_sel,
    input  logic [1:0]                 fmt_out,
    input  logic [VECTOR_LEN-1:0][7:0] operand_a,
    input  logic [VECTOR_LEN-1:0][7:0] operand_b,
    input  logic [31:0]                acc_seed,
    output logic [31:0]                result,
    output logic                       overflow,
    output logic                       underflow,
    output logic                       valid_out
);

    localparam int LANE_IDX_BITS = $clog2(VECTOR_LEN + 1);

    logic [VECTOR_LEN-1:0]                  a_sign;
    logic [VECTOR_LEN-1:0]                  b_sign;
    logic [VECTOR_LEN-1:0][EXP_BITS-1:0]    a_exp;
    logic [VECTOR_LEN-1:0][EXP_BITS-1:0]    b_exp;
    logic [VECTOR_LEN-1:0][MAN_BITS:0]      a_man;
    logic [VECTOR_LEN-1:0][MAN_BITS:0]      b_man;
    logic [VECTOR_LEN-1:0]                  a_zero;
    logic [VECTOR_LEN-1:0]                  b_zero;
    logic [VECTOR_LEN-1:0]                  a_inf;
    logic [VECTOR_LEN-1:0]                  b_inf;
    logic [VECTOR_LEN-1:0]                  a_nan;
    logic [VECTOR_LEN-1:0]                  b_nan;

    logic [VECTOR_LEN-1:0]                  mul_sign;
    logic [VECTOR_LEN-1:0][EXP_BITS:0]      mul_exp;
    logic [VECTOR_LEN-1:0][2*MAN_BITS+1:0]  mul_man;

    logic [VECTOR_LEN-1:0][24:0]            lane_man_aligned;
    logic [VECTOR_LEN-1:0][7:0]             lane_common_exp;
    logic [VECTOR_LEN-1:0]                  lane_guard;
    logic [VECTOR_LEN-1:0]                  lane_round;
    logic [VECTOR_LEN-1:0]                  lane_sticky;

    logic                                   acc_sign_reg;
    logic [7:0]                             acc_exp_reg;
    logic [24:0]                            acc_man_reg;
    logic                                   acc_guard_reg;
    logic                                   acc_round_reg;
    logic                                   acc_sticky_reg;
    logic [LANE_IDX_BITS-1:0]               lane_idx_reg;
    logic                                   done_reg;

    logic                                   sel_sign;
    logic [24:0]                            sel_man_aligned;
    logic [7:0]                             sel_common_exp;
    logic                                   sel_guard;
    logic                                   sel_round;
    logic                                   sel_sticky;

    logic                                   acc_sign_next;
    logic [7:0]                             acc_exp_next;
    logic [24:0]                            acc_man_next;
    logic                                   acc_guard_next;
    logic                                   acc_round_next;
    logic                                   acc_sticky_next;
    logic                                   acc_carry_next;

    logic                                   norm_sign;
    logic [7:0]                             norm_exp;
    logic [22:0]                            norm_man;

    genvar i;
    generate
        for (i = 0; i < VECTOR_LEN; i++) begin : g_lane
            input_decode #(
                .EXP_BITS (EXP_BITS),
                .MAN_BITS (MAN_BITS)
            ) u_dec_a (
                .raw_bits (operand_a[i]),
                .fmt_sel  (fmt_sel),
                .sign     (a_sign[i]),
                .exp      (a_exp[i]),
                .mantissa (a_man[i]),
                .is_zero  (a_zero[i]),
                .is_inf   (a_inf[i]),
                .is_nan   (a_nan[i])
            );

            input_decode #(
                .EXP_BITS (EXP_BITS),
                .MAN_BITS (MAN_BITS)
            ) u_dec_b (
                .raw_bits (operand_b[i]),
                .fmt_sel  (fmt_sel),
                .sign     (b_sign[i]),
                .exp      (b_exp[i]),
                .mantissa (b_man[i]),
                .is_zero  (b_zero[i]),
                .is_inf   (b_inf[i]),
                .is_nan   (b_nan[i])
            );

            fp_multiplier #(
                .EXP_BITS (EXP_BITS),
                .MAN_BITS (MAN_BITS)
            ) u_mul (
                .sign_a  (a_sign[i]),
                .sign_b  (b_sign[i]),
                .exp_a   (a_exp[i]),
                .exp_b   (b_exp[i]),
                .man_a   (a_man[i]),
                .man_b   (b_man[i]),
                .fmt_sel (fmt_sel),
                .sign_p  (mul_sign[i]),
                .exp_p   (mul_exp[i]),
                .man_p   (mul_man[i])
            );

            exp_aligner #(
                .EXP_BITS (EXP_BITS),
                .MAN_BITS (MAN_BITS)
            ) u_align (
                .exp_p       (mul_exp[i]),
                .man_p       (mul_man[i]),
                .acc_exp     (acc_exp_reg),
                .fmt_sel     (fmt_sel),
                .man_aligned (lane_man_aligned[i]),
                .common_exp  (lane_common_exp[i]),
                .guard_bit   (lane_guard[i]),
                .round_bit   (lane_round[i]),
                .sticky_bit  (lane_sticky[i])
            );
        end
    endgenerate

    // Lane-index mux: route the selected lane's aligned product into the accumulator; safe defaults when lane_idx_reg has stepped past the final lane.
    always_comb begin
        sel_sign        = 1'b0;
        sel_man_aligned = 25'b0;
        sel_common_exp  = acc_exp_reg;
        sel_guard       = 1'b0;
        sel_round       = 1'b0;
        sel_sticky      = 1'b0;

        if (lane_idx_reg < VECTOR_LEN[LANE_IDX_BITS-1:0]) begin
            sel_sign        = mul_sign[lane_idx_reg];
            sel_man_aligned = lane_man_aligned[lane_idx_reg];
            sel_common_exp  = lane_common_exp[lane_idx_reg];
            sel_guard       = lane_guard[lane_idx_reg];
            sel_round       = lane_round[lane_idx_reg];
            sel_sticky      = lane_sticky[lane_idx_reg];
        end
    end

    fp32_accumulator u_accum (
        .sign_p      (sel_sign),
        .man_aligned (sel_man_aligned),
        .common_exp  (sel_common_exp),
        .guard_bit   (sel_guard),
        .round_bit   (sel_round),
        .sticky_bit  (sel_sticky),
        .acc_sign    (acc_sign_reg),
        .acc_exp     (acc_exp_reg),
        .acc_man     (acc_man_reg),
        .acc_guard_in (acc_guard_reg),
        .acc_round_in (acc_round_reg),
        .acc_sticky_in(acc_sticky_reg),
        .sign_acc    (acc_sign_next),
        .exp_acc     (acc_exp_next),
        .man_acc     (acc_man_next),
        .guard_acc   (acc_guard_next),
        .round_acc   (acc_round_next),
        .sticky_acc  (acc_sticky_next),
        .carry_acc   (acc_carry_next)
    );

    // Sequential accumulator state: init from acc_seed, consume one lane per cycle, and renormalize any bit-25 carry immediately.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_sign_reg       <= acc_seed[31];
            acc_exp_reg        <= acc_seed[30:23];
            acc_man_reg        <= (acc_seed[30:23] == 8'h00) ?
                                  25'b0 : {1'b0, 1'b1, acc_seed[22:0]};
            acc_guard_reg      <= 1'b0;
            acc_round_reg      <= 1'b0;
            acc_sticky_reg     <= 1'b0;
            lane_idx_reg       <= '0;
            done_reg           <= 1'b0;
        end else if (!done_reg) begin
            acc_sign_reg       <= acc_sign_next;
            if (acc_carry_next) begin
                acc_exp_reg    <= acc_exp_next + 8'd1;
                acc_man_reg    <= {1'b1, acc_man_next[24:1]};
                acc_guard_reg  <= acc_man_next[0];
                acc_round_reg  <= acc_guard_next;
                acc_sticky_reg <= acc_round_next | acc_sticky_next;
            end else begin
                acc_exp_reg    <= acc_exp_next;
                acc_man_reg    <= acc_man_next;
                acc_guard_reg  <= acc_guard_next;
                acc_round_reg  <= acc_round_next;
                acc_sticky_reg <= acc_sticky_next;
            end
            lane_idx_reg       <= lane_idx_reg + 1'b1;

            if (lane_idx_reg == (VECTOR_LEN - 1)) begin
                done_reg <= 1'b1;
            end
        end
    end

    normalizer u_norm (
        .sign_in    (acc_sign_reg),
        .exp_in     (acc_exp_reg),
        .man_in     (acc_man_reg),
        .guard_bit  (acc_guard_reg),
        .round_bit  (acc_round_reg),
        .sticky_bit (acc_sticky_reg),
        .sign_out   (norm_sign),
        .exp_out    (norm_exp),
        .man_out    (norm_man),
        .overflow   (overflow),
        .underflow  (underflow)
    );

    output_pack u_pack (
        .sign_in (norm_sign),
        .exp_in  (norm_exp),
        .man_in  (norm_man),
        .fmt_out (fmt_out),
        .result  (result)
    );

    assign valid_out = done_reg;

endmodule
