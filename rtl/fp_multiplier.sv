module fp_multiplier #(
    parameter int EXP_BITS = 4,
    parameter int MAN_BITS = 3
) (
    input  logic                    sign_a,
    input  logic                    sign_b,
    input  logic [EXP_BITS-1:0]     exp_a,
    input  logic [EXP_BITS-1:0]     exp_b,
    input  logic [MAN_BITS:0]       man_a,
    input  logic [MAN_BITS:0]       man_b,
    input  logic [1:0]              fmt_sel,
    output logic                    sign_p,
    output logic [EXP_BITS:0]       exp_p,
    output logic [2*MAN_BITS+1:0]   man_p
);

    logic [EXP_BITS+MAN_BITS:0] packed_a;
    logic [EXP_BITS+MAN_BITS:0] packed_b;

    assign packed_a = {sign_a, exp_a, man_a[MAN_BITS-1:0]};
    assign packed_b = {sign_b, exp_b, man_b[MAN_BITS-1:0]};

    fp8_multiplier #(
        .EXP_BITS (EXP_BITS),
        .MAN_BITS (MAN_BITS)
    ) u_mul (
        .a       (packed_a),
        .b       (packed_b),
        .fmt_sel (fmt_sel),
        .sign_p  (sign_p),
        .exp_p   (exp_p),
        .man_p   (man_p)
    );

endmodule
