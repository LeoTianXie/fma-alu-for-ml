module fp8_multiplier #(
    parameter int EXP_BITS = 4,
    parameter int MAN_BITS = 3
) (
    input  logic [7:0]              a,
    input  logic [7:0]              b,
    input  logic [1:0]              fmt_sel,
    output logic                    sign_p,
    output logic [EXP_BITS+1:0]     exp_p,
    output logic [2*MAN_BITS+1:0]   man_p
);

    // Format-correct bias selection (OCP MX v1.0 Section 5.3):
    //   FP4 (E2M1)=1, E4M3=7, E5M2=15. Default to EXP_BITS-derived bias
    //   so unparameterized callers still get sane behavior.
    logic [4:0] bias;
    always_comb begin
        unique case (fmt_sel)
            2'b00:   bias = 5'd1;    // FP4 (E2M1)
            2'b01:   bias = 5'd7;    // E4M3
            2'b10:   bias = 5'd15;   // E5M2
            default: bias = 5'((1 << (EXP_BITS - 1)) - 1);
        endcase
    end

    logic                  sign_a;
    logic                  sign_b;
    logic [EXP_BITS-1:0]   exp_a;
    logic [EXP_BITS-1:0]   exp_b;
    logic [EXP_BITS-1:0]   exp_eff_a;
    logic [EXP_BITS-1:0]   exp_eff_b;
    logic [MAN_BITS:0]     man_a;
    logic [MAN_BITS:0]     man_b;
    logic                  zero_a;
    logic                  zero_b;
    logic                  subnormal_a;
    logic                  subnormal_b;
    logic signed [EXP_BITS+2:0] exp_sum_signed;

    logic [3:0]            fp4_a_hi;
    logic [3:0]            fp4_b_hi;
    logic [3:0]            fp4_a_lo;
    logic [3:0]            fp4_b_lo;
    logic [3:0]            prod_hi_unused;
    logic [3:0]            prod_lo_unused;

    assign sign_a = a[7];
    assign exp_a  = a[6:MAN_BITS];
    assign man_a  = {|exp_a, a[MAN_BITS-1:0]};
    assign zero_a = (exp_a == '0) && (a[MAN_BITS-1:0] == '0);
    assign subnormal_a = (exp_a == '0) && (a[MAN_BITS-1:0] != '0);
    assign exp_eff_a = subnormal_a ? {{(EXP_BITS-1){1'b0}}, 1'b1} : exp_a;

    assign sign_b = b[7];
    assign exp_b  = b[6:MAN_BITS];
    assign man_b  = {|exp_b, b[MAN_BITS-1:0]};
    assign zero_b = (exp_b == '0) && (b[MAN_BITS-1:0] == '0);
    assign subnormal_b = (exp_b == '0) && (b[MAN_BITS-1:0] != '0);
    assign exp_eff_b = subnormal_b ? {{(EXP_BITS-1){1'b0}}, 1'b1} : exp_b;

    assign exp_sum_signed = $signed({1'b0, exp_eff_a}) +
                            $signed({1'b0, exp_eff_b}) -
                            $signed({1'b0, bias});

    assign sign_p = sign_a ^ sign_b;
    assign exp_p  = (zero_a || zero_b) ? '0 : exp_sum_signed[EXP_BITS+1:0];
    assign man_p  = (zero_a || zero_b) ? '0 : (man_a * man_b);

    assign fp4_a_hi = {1'b0, man_a[MAN_BITS:MAN_BITS-1], 1'b0};
    assign fp4_b_hi = {1'b0, man_b[MAN_BITS:MAN_BITS-1], 1'b0};
    assign fp4_a_lo = {1'b0, 2'b00, man_a[0]};
    assign fp4_b_lo = {1'b0, 2'b00, man_b[0]};

    fp4_multiplier u_hi (
        .a      (fp4_a_hi),
        .b      (fp4_b_hi),
        .sign_p (),
        .exp_p  (),
        .man_p  (prod_hi_unused)
    );

    fp4_multiplier u_lo (
        .a      (fp4_a_lo),
        .b      (fp4_b_lo),
        .sign_p (),
        .exp_p  (),
        .man_p  (prod_lo_unused)
    );

endmodule
