`timescale 1ns/1ps

module fp32_accumulator_tb;

    // -------------------------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------------------------
    logic        sign_p;
    logic [24:0] man_aligned;
    logic [7:0]  common_exp;
    logic        guard_bit;
    logic        round_bit;
    logic        sticky_bit;
    logic        acc_sign;
    logic [7:0]  acc_exp;
    logic [24:0] acc_man;
    logic        sign_acc;
    logic [7:0]  exp_acc;
    logic [24:0] man_acc;
    logic        guard_acc;
    logic        round_acc;
    logic        sticky_acc;

    fp32_accumulator dut (.*);

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;
    logic [23:0] sweep_acc_low;

    // -------------------------------------------------------------------------
    // Reference model
    // -------------------------------------------------------------------------
    task automatic calc_shift_grs(
        input  logic [24:0] in_man,
        input  logic [7:0]  shift_amount,
        output logic [24:0] r_man_aligned,
        output logic        r_guard,
        output logic        r_round,
        output logic        r_sticky
    );
        r_man_aligned = 25'b0;
        r_guard       = 1'b0;
        r_round       = 1'b0;
        r_sticky      = 1'b0;

        if (shift_amount <= 8'd24) begin
            r_man_aligned = in_man >> shift_amount[4:0];
        end

        if ((shift_amount >= 8'd1) && (shift_amount <= 8'd25)) begin
            r_guard = in_man[shift_amount - 8'd1];
        end

        if ((shift_amount >= 8'd2) && (shift_amount <= 8'd26)) begin
            r_round = in_man[shift_amount - 8'd2];
        end

        if (shift_amount >= 8'd3) begin
            for (int i = 0; i < 25; i++) begin
                if (i <= (shift_amount - 8'd3)) begin
                    r_sticky = r_sticky | in_man[i];
                end
            end
        end
    endtask

    task automatic ref_model(
        input  logic        r_sign_p,
        input  logic [24:0] r_man_aligned,
        input  logic [7:0]  r_common_exp,
        input  logic        r_guard_bit,
        input  logic        r_round_bit,
        input  logic        r_sticky_bit,
        input  logic        r_acc_sign,
        input  logic [7:0]  r_acc_exp,
        input  logic [24:0] r_acc_man,
        output logic        r_sign_acc,
        output logic [7:0]  r_exp_acc,
        output logic [24:0] r_man_acc,
        output logic        r_guard_acc,
        output logic        r_round_acc,
        output logic        r_sticky_acc
    );
        logic [7:0]  acc_shift_amount;
        logic [24:0] acc_man_shifted;
        logic        acc_guard;
        logic        acc_round;
        logic        acc_sticky;
        logic [27:0] product_mag_ext;
        logic [27:0] acc_mag_ext;
        logic [24:0] larger_man;
        logic [24:0] smaller_man;
        logic        larger_sign;
        logic [25:0] same_sign_sum;
        logic [25:0] opposite_sign_diff;

        acc_shift_amount = (r_common_exp > r_acc_exp) ? (r_common_exp - r_acc_exp) : 8'd0;
        calc_shift_grs(r_acc_man, acc_shift_amount, acc_man_shifted,
                       acc_guard, acc_round, acc_sticky);

        r_exp_acc    = r_common_exp;
        r_guard_acc  = r_guard_bit | acc_guard;
        r_round_acc  = r_round_bit | acc_round;
        r_sticky_acc = r_sticky_bit | acc_sticky;

        product_mag_ext = {r_man_aligned, r_guard_bit, r_round_bit, r_sticky_bit};
        acc_mag_ext     = {acc_man_shifted, acc_guard, acc_round, acc_sticky};

        if (product_mag_ext >= acc_mag_ext) begin
            larger_man  = r_man_aligned;
            smaller_man = acc_man_shifted;
            larger_sign = r_sign_p;
        end else begin
            larger_man  = acc_man_shifted;
            smaller_man = r_man_aligned;
            larger_sign = r_acc_sign;
        end

        if (r_sign_p == r_acc_sign) begin
            same_sign_sum = {1'b0, r_man_aligned} + {1'b0, acc_man_shifted};
            r_man_acc     = same_sign_sum[24:0];
            r_sign_acc    = r_sign_p;
        end else begin
            opposite_sign_diff = {1'b0, larger_man} - {1'b0, smaller_man};
            r_man_acc          = opposite_sign_diff[24:0];
            r_sign_acc         = ((r_man_acc == 25'b0) &&
                                  !r_guard_acc && !r_round_acc && !r_sticky_acc) ?
                                 1'b0 : larger_sign;
        end
    endtask

    // -------------------------------------------------------------------------
    // Compare helper
    // -------------------------------------------------------------------------
    task automatic check(input string label);
        logic        r_sign;
        logic [7:0]  r_exp;
        logic [24:0] r_man;
        logic        r_guard, r_round, r_sticky;

        ref_model(sign_p, man_aligned, common_exp, guard_bit, round_bit, sticky_bit,
                  acc_sign, acc_exp, acc_man,
                  r_sign, r_exp, r_man, r_guard, r_round, r_sticky);

        if (sign_acc !== r_sign || exp_acc !== r_exp || man_acc !== r_man ||
            guard_acc !== r_guard || round_acc !== r_round || sticky_acc !== r_sticky) begin
            $display("FAIL [%-38s] p=(s=%b man=%025b exp=%0d grs=%b%b%b) acc=(s=%b man=%025b exp=%0d) | got s=%b exp=%0d man=%025b grs=%b%b%b | exp s=%b exp=%0d man=%025b grs=%b%b%b",
                     label,
                     sign_p, man_aligned, common_exp, guard_bit, round_bit, sticky_bit,
                     acc_sign, acc_man, acc_exp,
                     sign_acc, exp_acc, man_acc, guard_acc, round_acc, sticky_acc,
                     r_sign, r_exp, r_man, r_guard, r_round, r_sticky);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    task automatic apply_and_check(
        input string       label,
        input logic        t_sign_p,
        input logic [24:0] t_man_aligned,
        input logic [7:0]  t_common_exp,
        input logic        t_guard_bit,
        input logic        t_round_bit,
        input logic        t_sticky_bit,
        input logic        t_acc_sign,
        input logic [7:0]  t_acc_exp,
        input logic [24:0] t_acc_man
    );
        sign_p      = t_sign_p;
        man_aligned = t_man_aligned;
        common_exp  = t_common_exp;
        guard_bit   = t_guard_bit;
        round_bit   = t_round_bit;
        sticky_bit  = t_sticky_bit;
        acc_sign    = t_acc_sign;
        acc_exp     = t_acc_exp;
        acc_man     = t_acc_man;
        #1;
        check(label);
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // Basic same-sign add and carry into bit 24.
        apply_and_check("same sign simple add",
                        1'b0, 25'h0000010, 8'd127, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0000001);

        apply_and_check("carry into bit24",
                        1'b0, 25'h0FFFFFF, 8'd127, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0000001);

        // Long same-sign accumulation proxy: bit 24 is already saturated and a
        // new positive add would generate a 26th bit. The public 25-bit contract
        // intentionally drops that bit, so the reference checks truncation.
        apply_and_check("same sign saturated bit24 overflow truncates",
                        1'b0, 25'h1000000, 8'd130, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd130, 25'h1000000);

        apply_and_check("same sign saturated bit24 plus low carry",
                        1'b1, 25'h1FFFFFF, 8'd130, 1'b0, 1'b0, 1'b0,
                        1'b1, 8'd130, 25'h0000001);

        // Opposite-sign cancellation to exactly zero must force +0.
        apply_and_check("opposite sign exact cancel positive product",
                        1'b0, 25'h0001234, 8'd127, 1'b0, 1'b0, 1'b0,
                        1'b1, 8'd127, 25'h0001234);

        apply_and_check("opposite sign exact cancel negative product",
                        1'b1, 25'h0001234, 8'd127, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0001234);

        // Equal visible mantissas, but product G/R/S makes the product larger.
        apply_and_check("opposite sign tie broken by product guard",
                        1'b1, 25'h0000010, 8'd127, 1'b1, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0000010);

        // Equal visible mantissas, but accumulator shift G/R/S makes acc larger.
        apply_and_check("opposite sign tie broken by acc guard",
                        1'b1, 25'h0000010, 8'd128, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0000021);

        // Tiny product into huge accumulator: accumulator was already common-exp
        // sized by Stage 3, so product-side sticky is preserved through this block.
        apply_and_check("tiny product into huge acc sticky preserved",
                        1'b0, 25'h0000000, 8'd200, 1'b0, 1'b0, 1'b1,
                        1'b0, 8'd200, 25'h1800000);

        // Huge product with smaller accumulator: this block shifts acc and must
        // preserve shifted-off accumulator precision.
        apply_and_check("product larger shifts acc sticky",
                        1'b0, 25'h0800000, 8'd160, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd133, 25'h0000007);

        apply_and_check("product larger shifts acc guard round",
                        1'b0, 25'h0800000, 8'd129, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0000007);

        // Subtraction where larger/smaller swap because accumulator is shifted.
        apply_and_check("subtraction product larger after acc shift",
                        1'b0, 25'h0000020, 8'd130, 1'b0, 1'b0, 1'b0,
                        1'b1, 8'd127, 25'h00000F0);

        apply_and_check("subtraction acc larger same exponent",
                        1'b0, 25'h0000020, 8'd130, 1'b0, 1'b0, 1'b0,
                        1'b1, 8'd130, 25'h00000F0);

        // Shift boundary probes for accumulator-side alignment.
        apply_and_check("acc shift 24",
                        1'b0, 25'h0000000, 8'd151, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0FFFFFF);

        apply_and_check("acc shift 25",
                        1'b0, 25'h0000000, 8'd152, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0FFFFFF);

        apply_and_check("acc shift 26",
                        1'b0, 25'h0000000, 8'd153, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0FFFFFF);

        apply_and_check("acc shift 27 sticky only",
                        1'b0, 25'h0000000, 8'd154, 1'b0, 1'b0, 1'b0,
                        1'b0, 8'd127, 25'h0FFFFFF);

        // Deterministic sweep across signs, exponents, mantissas, and G/R/S.
        for (int i = 0; i < 512; i++) begin
            sign_p      = i[0];
            acc_sign    = i[1];
            common_exp  = (8'd120 + (i[7:0] % 8'd48));
            acc_exp     = (8'd112 + ((i * 3) % 8'd56));
            man_aligned = {i[0], i[23:0]} ^ 25'h0A5A5A5;
            sweep_acc_low = i * 17;
            acc_man     = {i[1], sweep_acc_low} ^ 25'h05A5A5A;
            guard_bit   = i[2];
            round_bit   = i[3];
            sticky_bit  = i[4];
            #1;
            check($sformatf("sweep %0d", i));
        end

        // Summary
        $display("");
        $display("---------------------------------------------------");
        $display("RESULTS: %0d passed, %0d failed (total %0d checks)",
                 pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("*** FAILURES DETECTED ***");
        $display("---------------------------------------------------");
    end

endmodule
