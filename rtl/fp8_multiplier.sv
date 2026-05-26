module fp8_multiplier #(
    parameter int EXP_BITS = 4,
    parameter int MAN_BITS = 3
) (
    input  logic [7:0]              a,
    input  logic [7:0]              b,
    output logic                    sign_p,
    output logic [EXP_BITS:0]       exp_p,
    output logic [2*MAN_BITS+1:0]   man_p
);

    localparam int BIAS = (1 << (EXP_BITS - 1)) - 1;

    logic                  sign_a;
    logic                  sign_b;
    logic [EXP_BITS-1:0]   exp_a;
    logic [EXP_BITS-1:0]   exp_b;
    logic [MAN_BITS:0]     man_a;
    logic [MAN_BITS:0]     man_b;

    logic [3:0]            fp4_a_hi;
    logic [3:0]            fp4_b_hi;
    logic [3:0]            fp4_a_lo;
    logic [3:0]            fp4_b_lo;
    logic [3:0]            prod_hi_unused;
    logic [3:0]            prod_lo_unused;

    assign sign_a = a[7];
    assign exp_a  = a[6:MAN_BITS];
    assign man_a  = {1'b1, a[MAN_BITS-1:0]};

    assign sign_b = b[7];
    assign exp_b  = b[6:MAN_BITS];
    assign man_b  = {1'b1, b[MAN_BITS-1:0]};

    assign sign_p = sign_a ^ sign_b;
    assign exp_p  = {1'b0, exp_a} + {1'b0, exp_b} - (EXP_BITS + 1)'(BIAS);
    assign man_p  = man_a * man_b;

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
