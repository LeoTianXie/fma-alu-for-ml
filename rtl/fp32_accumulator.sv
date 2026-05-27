module fp32_accumulator (
    input  logic        sign_p,
    input  logic [24:0] man_aligned,
    input  logic [7:0]  common_exp,
    input  logic        guard_bit,
    input  logic        round_bit,
    input  logic        sticky_bit,
    input  logic        acc_sign,
    input  logic [7:0]  acc_exp,
    input  logic [24:0] acc_man,
    input  logic        acc_guard_in,
    input  logic        acc_round_in,
    input  logic        acc_sticky_in,
    output logic        sign_acc,
    output logic [7:0]  exp_acc,
    output logic [24:0] man_acc,
    output logic        guard_acc,
    output logic        round_acc,
    output logic        sticky_acc,
    output logic        carry_acc
);

    logic [7:0]  acc_shift_amount;
    logic [27:0] acc_ext;
    logic [27:0] acc_ext_shifted;
    logic [24:0] acc_man_aligned;
    logic        acc_guard;
    logic        acc_round;
    logic        acc_sticky;

    logic        signs_match;
    logic        product_ge_acc;
    logic [27:0] product_mag_ext;
    logic [27:0] acc_mag_ext;
    logic [24:0] larger_man;
    logic [24:0] smaller_man;
    logic        larger_sign;

    logic [23:0] add_a;
    logic [23:0] add_b;
    logic        add_cin;
    logic [7:0]  sum_low;
    logic [7:0]  sum_mid;
    logic [7:0]  sum_high;
    logic        c0;
    logic        c1;
    logic        c2;
    logic [23:0] sum_24;
    logic        result_bit24;
    logic        result_is_zero;

    assign acc_shift_amount = (common_exp > acc_exp) ? (common_exp - acc_exp) : 8'd0;

    assign acc_ext = {acc_man, acc_guard_in, acc_round_in, acc_sticky_in};

    // Right-shift the accumulator's mantissa+G/R/S stream to the common exponent.
    always_comb begin
        acc_ext_shifted = 28'b0;
        acc_man_aligned = 25'b0;
        acc_guard       = 1'b0;
        acc_round       = 1'b0;
        acc_sticky      = 1'b0;

        if (acc_shift_amount <= 8'd27) begin
            for (int i = 0; i < 28; i++) begin
                if ((i + acc_shift_amount) < 28) begin
                    acc_ext_shifted[i] = acc_ext[i + acc_shift_amount];
                end
            end

            acc_man_aligned = acc_ext_shifted[27:3];
            acc_guard       = acc_ext_shifted[2];
            acc_round       = acc_ext_shifted[1];
            acc_sticky      = acc_ext_shifted[0];

            for (int i = 0; i < 28; i++) begin
                if ((acc_shift_amount != 8'd0) && (i < acc_shift_amount)) begin
                    acc_sticky = acc_sticky | acc_ext[i];
                end
            end
        end else begin
            acc_sticky = |acc_ext;
        end
    end

    always_comb begin
        carry_acc = 1'b0;
        if (signs_match) begin
            unique case ({man_aligned[24], acc_man_aligned[24], c2})
                3'b000,
                3'b001,
                3'b010,
                3'b100: carry_acc = 1'b0;
                default: carry_acc = 1'b1;
            endcase
        end
    end

    assign signs_match     = (sign_p == acc_sign);
    assign product_mag_ext = {man_aligned, guard_bit, round_bit, sticky_bit};
    assign acc_mag_ext     = {acc_man_aligned, acc_guard, acc_round, acc_sticky};
    assign product_ge_acc  = (product_mag_ext >= acc_mag_ext);
    assign larger_man     = product_ge_acc ? man_aligned : acc_man_aligned;
    assign smaller_man    = product_ge_acc ? acc_man_aligned : man_aligned;
    assign larger_sign    = product_ge_acc ? sign_p : acc_sign;

    // Select add operands, using two's-complement subtraction when signs differ.
    always_comb begin
        if (signs_match) begin
            add_a   = man_aligned[23:0];
            add_b   = acc_man_aligned[23:0];
            add_cin = 1'b0;
        end else begin
            add_a   = larger_man[23:0];
            add_b   = ~smaller_man[23:0];
            add_cin = 1'b1;
        end
    end

    mantissa_adder u_low (
        .a    (add_a[7:0]),
        .b    (add_b[7:0]),
        .cin  (add_cin),
        .sum  (sum_low),
        .cout (c0)
    );

    mantissa_adder u_mid (
        .a    (add_a[15:8]),
        .b    (add_b[15:8]),
        .cin  (c0),
        .sum  (sum_mid),
        .cout (c1)
    );

    mantissa_adder u_high (
        .a    (add_a[23:16]),
        .b    (add_b[23:16]),
        .cin  (c1),
        .sum  (sum_high),
        .cout (c2)
    );

    assign sum_24 = {sum_high, sum_mid, sum_low};

    // Assemble the accumulator result, carry slot, sign, exponent, and combined G/R/S bits.
    always_comb begin
        exp_acc    = common_exp;
        guard_acc  = guard_bit | acc_guard;
        round_acc  = round_bit | acc_round;
        sticky_acc = sticky_bit | acc_sticky;
        result_is_zero = 1'b0;

        if (signs_match) begin
            result_bit24 = man_aligned[24] ^ acc_man_aligned[24] ^ c2;
            man_acc      = {result_bit24, sum_24};
            sign_acc     = sign_p;
        end else begin
            result_bit24 = larger_man[24] ^ ~smaller_man[24] ^ c2;
            man_acc      = {result_bit24, sum_24};
            result_is_zero = (man_acc == 25'b0) & ~guard_acc & ~round_acc & ~sticky_acc;
            sign_acc       = result_is_zero ? 1'b0 : larger_sign;
        end
    end

endmodule
