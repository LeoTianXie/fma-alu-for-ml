module input_decode #(
    parameter int EXP_BITS = 4,
    parameter int MAN_BITS = 3
) (
    input  logic [EXP_BITS+MAN_BITS:0] raw_bits,
    input  logic [1:0]                 fmt_sel,
    output logic                       sign,
    output logic [EXP_BITS-1:0]        exp,
    output logic [MAN_BITS:0]          mantissa,
    output logic                       is_zero,
    output logic                       is_inf,
    output logic                       is_nan
);

    // Decode the selected FP format into fields, implicit mantissa bit, and special flags.
    always_comb begin
        sign     = 1'b0;
        exp      = '0;
        mantissa = '0;
        is_zero  = 1'b0;
        is_inf   = 1'b0;
        is_nan   = 1'b0;

        unique case (fmt_sel)
            2'b00: begin
                sign          = raw_bits[3];
                exp           = raw_bits[2:1];
                mantissa      = '0;
                mantissa[MAN_BITS-1] = raw_bits[0];
                mantissa[MAN_BITS] = (raw_bits[2:1] != 2'b00);
                is_zero       = (raw_bits[2:1] == 2'b00) & (raw_bits[0] == 1'b0);
                is_inf        = 1'b0;
                is_nan        = 1'b0;
            end

            2'b01: begin
                sign          = raw_bits[7];
                exp           = raw_bits[6:3];
                mantissa      = '0;
                mantissa[MAN_BITS] = (raw_bits[6:3] != 4'h0);
                mantissa[2:0] = raw_bits[2:0];
                is_zero       = (raw_bits[6:3] == 4'h0) & (raw_bits[2:0] == 3'b000);
                is_inf        = 1'b0;
                is_nan        = (raw_bits[6:3] == 4'hF);
            end

            2'b10: begin
                sign          = raw_bits[7];
                exp           = raw_bits[6:2];
                mantissa      = '0;
                mantissa[MAN_BITS] = (raw_bits[6:2] != 5'h00);
                mantissa[1:0] = raw_bits[1:0];
                is_zero       = (raw_bits[6:2] == 5'h00) & (raw_bits[1:0] == 2'b00);
                is_inf        = (raw_bits[6:2] == 5'h1F) & (raw_bits[1:0] == 2'b00);
                is_nan        = (raw_bits[6:2] == 5'h1F) & (raw_bits[1:0] != 2'b00);
            end

            default: begin
                sign = raw_bits[EXP_BITS+MAN_BITS];
            end
        endcase
    end

endmodule
