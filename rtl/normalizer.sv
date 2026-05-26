module normalizer (
    input  logic        sign_in,
    input  logic [7:0]  exp_in,
    input  logic [24:0] man_in,
    input  logic        guard_bit,
    input  logic        round_bit,
    input  logic        sticky_bit,
    output logic        sign_out,
    output logic [7:0]  exp_out,
    output logic [22:0] man_out,
    output logic        overflow,
    output logic        underflow
);

    logic signed [9:0] pre_exp;
    logic signed [9:0] norm_exp;
    logic signed [9:0] final_exp;
    logic [23:0]       pre_man;
    logic              pre_guard;
    logic              pre_round;
    logic              pre_sticky;
    logic [4:0]        lz;
    logic [26:0]       extended_man;
    logic [26:0]       shifted_man;
    logic [23:0]       norm_man;
    logic              norm_guard;
    logic              norm_round;
    logic              norm_sticky;
    logic              round_up;
    logic [24:0]       rounded_man;
    logic [23:0]       final_man;
    logic              is_zero;

    // Stage 1: absorb the bit-24 carry slot; the displaced LSB folds into G/R/S.
    always_comb begin
        if (man_in[24]) begin
            pre_man    = man_in[24:1];
            pre_guard  = man_in[0];
            pre_round  = guard_bit;
            pre_sticky = round_bit | sticky_bit;
            pre_exp    = {2'b00, exp_in} + 10'sd1;
        end else begin
            pre_man    = man_in[23:0];
            pre_guard  = guard_bit;
            pre_round  = round_bit;
            pre_sticky = sticky_bit;
            pre_exp    = {2'b00, exp_in};
        end
    end

    // Stage 2: priority-encode the leading-zero count of pre_man (0..24).
    always_comb begin
        lz = 5'd24;

        for (int i = 23; i >= 0; i--) begin
            if (pre_man[i]) begin
                lz = 5'(23 - i);
                break;
            end
        end
    end

    assign extended_man = {pre_man, pre_guard, pre_round, pre_sticky};
    assign shifted_man  = extended_man << lz;
    assign norm_man     = shifted_man[26:3];
    assign norm_guard   = shifted_man[2];
    assign norm_round   = shifted_man[1];
    assign norm_sticky  = shifted_man[0] | (pre_sticky & (lz >= 5'd4));
    assign norm_exp     = pre_exp - {5'b00000, lz};

    assign round_up     = norm_guard & (norm_round | norm_sticky | norm_man[0]);
    assign rounded_man  = {1'b0, norm_man} + {24'b0, round_up};

    // Stage 4b: post-rounding renormalize if rounding bumped mantissa to 2.0.
    always_comb begin
        if (rounded_man[24]) begin
            final_man = rounded_man[24:1];
            final_exp = norm_exp + 10'sd1;
        end else begin
            final_man = rounded_man[23:0];
            final_exp = norm_exp;
        end
    end

    assign is_zero = (pre_man == 24'b0) & ~pre_guard & ~pre_round & ~pre_sticky;

    // Stage 5: assemble outputs, handling zero/overflow/underflow special cases.
    always_comb begin
        sign_out  = sign_in;
        exp_out   = 8'h00;
        man_out   = 23'h0;
        overflow  = 1'b0;
        underflow = 1'b0;

        if (is_zero) begin
            exp_out = 8'h00;
            man_out = 23'h0;
        end else if (final_exp >= 10'sd255) begin
            exp_out  = 8'hFF;
            man_out  = 23'h0;
            overflow = 1'b1;
        end else if (final_exp <= 10'sd0) begin
            exp_out   = 8'h00;
            man_out   = 23'h0;
            underflow = (final_man != 24'b0);
        end else begin
            // Safe truncation: preceding else-if branches already filtered final_exp outside [1, 254].
            exp_out = final_exp[7:0];
            man_out = final_man[22:0];
        end
    end

endmodule
