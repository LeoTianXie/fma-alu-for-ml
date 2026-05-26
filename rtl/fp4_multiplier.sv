module fp4_multiplier (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic       sign_p,
    output logic [2:0] exp_p,
    output logic [3:0] man_p
);

    logic       sign_a;
    logic       sign_b;
    logic [1:0] exp_a;
    logic [1:0] exp_b;
    logic [1:0] man_a;
    logic [1:0] man_b;

    assign sign_a = a[3];
    assign exp_a  = a[2:1];
    assign man_a  = {1'b1, a[0]};

    assign sign_b = b[3];
    assign exp_b  = b[2:1];
    assign man_b  = {1'b1, b[0]};

    assign sign_p = sign_a ^ sign_b;
    assign man_p  = man_a * man_b;
    assign exp_p  = {1'b0, exp_a} + {1'b0, exp_b} - 3'd1;

endmodule
