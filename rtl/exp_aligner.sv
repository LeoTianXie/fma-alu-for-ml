module exp_aligner #(
    parameter int EXP_BITS = 4,
    parameter int MAN_BITS = 3
) (
    input  logic [EXP_BITS:0]       exp_p,
    input  logic [2*MAN_BITS+1:0]   man_p,
    input  logic [7:0]              acc_exp,
    input  logic [1:0]              fmt_sel,
    output logic [24:0]             man_aligned,
    output logic [7:0]              common_exp,
    output logic                    guard_bit,
    output logic                    round_bit,
    output logic                    sticky_bit
);

    localparam int LSHIFT = 23 - 2*MAN_BITS;

    // Format-correct BIAS_DIFF = 127 - bias(fmt). FP4=126, E4M3=120, E5M2=112.
    logic [7:0] bias_diff;
    always_comb begin
        unique case (fmt_sel)
            2'b00:   bias_diff = 8'd126;  // FP4
            2'b01:   bias_diff = 8'd120;  // E4M3
            2'b10:   bias_diff = 8'd112;  // E5M2
            default: bias_diff = 8'(127 - ((1 << (EXP_BITS - 1)) - 1));
        endcase
    end

    logic                  ovf;
    logic [EXP_BITS+1:0]   exp_p_norm;
    logic [2*MAN_BITS+1:0] man_p_norm;
    logic [24:0]           man_fp32;
    logic [7:0]            product_fp32_exp;
    logic                  acc_larger;
    logic [7:0]            shift_amount;

    assign ovf        = man_p[2*MAN_BITS+1];
    assign man_p_norm = ovf ? (man_p >> 1) : man_p;
    assign exp_p_norm = ovf ? ({1'b0, exp_p} + 1'b1) : {1'b0, exp_p};

    assign man_fp32 = {1'b0, man_p_norm[2*MAN_BITS:0], {LSHIFT{1'b0}}};

    assign product_fp32_exp = 8'(exp_p_norm) + bias_diff;

    assign acc_larger   = (acc_exp > product_fp32_exp);
    assign shift_amount = acc_larger ? (acc_exp - product_fp32_exp) : 8'd0;
    assign common_exp   = acc_larger ? acc_exp : product_fp32_exp;

    // Right-shift the product mantissa to the common exponent and preserve G/R/S bits.
    always_comb begin
        man_aligned = 25'b0;
        guard_bit   = 1'b0;
        round_bit   = 1'b0;
        sticky_bit  = 1'b0;

        unique case (1'b1)
            (shift_amount == 8'd0): begin
                man_aligned = man_fp32;
            end

            (shift_amount == 8'd1): begin
                man_aligned = man_fp32 >> 1;
                guard_bit   = man_fp32[0];
            end

            (shift_amount == 8'd2): begin
                man_aligned = man_fp32 >> 2;
                guard_bit   = man_fp32[1];
                round_bit   = man_fp32[0];
            end

            ((shift_amount >= 8'd3) && (shift_amount <= 8'd24)): begin
                man_aligned = man_fp32 >> shift_amount[4:0];
                guard_bit   = man_fp32[shift_amount[4:0] - 5'd1];
                round_bit   = man_fp32[shift_amount[4:0] - 5'd2];

                for (int i = 0; i < 25; i++) begin
                    if (i + 3 <= shift_amount) begin
                        sticky_bit = sticky_bit | man_fp32[i];
                    end
                end
            end

            (shift_amount == 8'd25): begin
                guard_bit  = man_fp32[24];
                round_bit  = man_fp32[23];
                sticky_bit = |man_fp32[22:0];
            end

            (shift_amount == 8'd26): begin
                round_bit  = man_fp32[24];
                sticky_bit = |man_fp32[23:0];
            end

            default: begin
                sticky_bit = |man_fp32;
            end
        endcase
    end

endmodule
