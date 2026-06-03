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
    output logic [EXP_BITS+1:0]     exp_p,
    output logic [2*MAN_BITS+1:0]   man_p
);

    logic [4:0] bias;

    always_comb begin
        unique case (fmt_sel)
            2'b00:   bias = 5'd1;    // FP4 (E2M1)
            2'b01:   bias = 5'd7;    // E4M3
            2'b10:   bias = 5'd15;   // E5M2
            default: bias = 5'((1 << (EXP_BITS - 1)) - 1);
        endcase
    end

    logic                    zero_a;
    logic                    zero_b;
    logic                    subnormal_a;
    logic                    subnormal_b;
    logic [EXP_BITS-1:0]     exp_eff_a;
    logic [EXP_BITS-1:0]     exp_eff_b;
    logic signed [EXP_BITS+2:0] exp_sum_signed;

    assign zero_a      = (exp_a == '0) && (man_a[MAN_BITS-1:0] == '0);
    assign zero_b      = (exp_b == '0) && (man_b[MAN_BITS-1:0] == '0);
    assign subnormal_a = (exp_a == '0) && (man_a[MAN_BITS-1:0] != '0);
    assign subnormal_b = (exp_b == '0) && (man_b[MAN_BITS-1:0] != '0);
    assign exp_eff_a   = subnormal_a ? {{(EXP_BITS-1){1'b0}}, 1'b1} : exp_a;
    assign exp_eff_b   = subnormal_b ? {{(EXP_BITS-1){1'b0}}, 1'b1} : exp_b;

    assign exp_sum_signed = $signed({1'b0, exp_eff_a}) +
                            $signed({1'b0, exp_eff_b}) -
                            $signed({1'b0, bias});

    assign sign_p = sign_a ^ sign_b;
    assign exp_p  = (zero_a || zero_b) ? '0 : exp_sum_signed[EXP_BITS+1:0];
    assign man_p  = (zero_a || zero_b) ? '0 : (man_a * man_b);

endmodule
