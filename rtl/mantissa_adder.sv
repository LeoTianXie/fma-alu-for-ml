module mantissa_adder (
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic       cin,
    output logic [7:0] sum,
    output logic       cout
);

    assign {cout, sum} = a + b + cin;

endmodule
