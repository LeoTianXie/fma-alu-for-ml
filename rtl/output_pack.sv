module output_pack (
    input  logic        sign_in,
    input  logic [7:0]  exp_in,
    input  logic [22:0] man_in,
    input  logic [1:0]  fmt_out,
    output logic [31:0] result
);

    logic signed [8:0] fp4_exp_s;
    logic signed [8:0] e4m3_exp_s;
    logic signed [8:0] e5m2_exp_s;

    logic              fp4_underflow;
    logic              fp4_overflow;
    logic              e4m3_underflow;
    logic              e4m3_overflow;
    logic              e5m2_underflow;
    logic              e5m2_overflow;

    logic              fp4_man;
    logic [2:0]        e4m3_man;
    logic [1:0]        e5m2_man;

    assign fp4_exp_s      = {1'b0, exp_in} - 9'sd126;
    assign e4m3_exp_s     = {1'b0, exp_in} - 9'sd120;
    assign e5m2_exp_s     = {1'b0, exp_in} - 9'sd112;

    assign fp4_underflow  = (fp4_exp_s < 9'sd1);
    assign fp4_overflow   = (fp4_exp_s > 9'sd2);
    assign e4m3_underflow = (e4m3_exp_s < 9'sd1);
    assign e4m3_overflow  = (e4m3_exp_s > 9'sd14);
    assign e5m2_underflow = (e5m2_exp_s < 9'sd1);
    assign e5m2_overflow  = (e5m2_exp_s > 9'sd30);

    assign fp4_man        = man_in[22];
    assign e4m3_man       = man_in[22:20];
    assign e5m2_man       = man_in[22:21];

    // Pack normalized FP32 fields into the selected output format with narrow-format saturation.
    always_comb begin
        result = 32'h0000_0000;

        unique case (fmt_out)
            2'b00: begin
                if (fp4_underflow) begin
                    result[3:0] = {sign_in, 3'b000};
                end else if (fp4_overflow) begin
                    result[3:0] = {sign_in, 2'b11, 1'b1};   // FP4 max normal = +/-6.0 (OCP MX Table 5)
                end else begin
                    result[3:0] = {sign_in, fp4_exp_s[1:0], fp4_man};
                end
            end

            2'b01: begin
                if (e4m3_underflow) begin
                    result[7:0] = {sign_in, 7'b000_0000};
                end else if (e4m3_overflow) begin
                    result[7:0] = {sign_in, 4'b1111, 3'b110};   // E4M3 max normal = +/-448 (OCP FP8 spec)
                end else begin
                    result[7:0] = {sign_in, e4m3_exp_s[3:0], e4m3_man};
                end
            end

            2'b10: begin
                if (e5m2_underflow) begin
                    result[7:0] = {sign_in, 7'b000_0000};
                end else if (e5m2_overflow) begin
                    result[7:0] = {sign_in, 5'b11110, 2'b11};
                end else begin
                    result[7:0] = {sign_in, e5m2_exp_s[4:0], e5m2_man};
                end
            end

            default: begin
                // FP16 is stubbed; fmt_out=2'b11 is repurposed as FP32 passthrough.
                result = {sign_in, exp_in, man_in};
            end
        endcase
    end

endmodule
