`timescale 1ns/1ps

module exp_aligner_tb;

    // -------------------------------------------------------------------------
    // E4M3 DUT  (EXP_BITS=4, MAN_BITS=3, FP8 bias=7)
    // -------------------------------------------------------------------------
    logic [4:0] exp4;
    logic [7:0] man4;
    logic [7:0] acc_exp4;
    logic [24:0] man_aligned4;
    logic [7:0] common_exp4;
    logic guard4, round4, sticky4;

    exp_aligner #(.EXP_BITS(4), .MAN_BITS(3)) dut_e4m3 (
        .exp_p       (exp4),
        .man_p       (man4),
        .acc_exp     (acc_exp4),
        .man_aligned (man_aligned4),
        .common_exp  (common_exp4),
        .guard_bit   (guard4),
        .round_bit   (round4),
        .sticky_bit  (sticky4)
    );

    // -------------------------------------------------------------------------
    // E5M2 DUT  (EXP_BITS=5, MAN_BITS=2, FP8 bias=15)
    // -------------------------------------------------------------------------
    logic [5:0] exp5;
    logic [5:0] man5;
    logic [7:0] acc_exp5;
    logic [24:0] man_aligned5;
    logic [7:0] common_exp5;
    logic guard5, round5, sticky5;

    exp_aligner #(.EXP_BITS(5), .MAN_BITS(2)) dut_e5m2 (
        .exp_p       (exp5),
        .man_p       (man5),
        .acc_exp     (acc_exp5),
        .man_aligned (man_aligned5),
        .common_exp  (common_exp5),
        .guard_bit   (guard5),
        .round_bit   (round5),
        .sticky_bit  (sticky5)
    );

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // Reference models
    // -------------------------------------------------------------------------
    task automatic ref_e4m3(
        input  logic [4:0]  r_exp_p,
        input  logic [7:0]  r_man_p,
        input  logic [7:0]  r_acc_exp,
        output logic [24:0] r_man_aligned,
        output logic [7:0]  r_common_exp,
        output logic        r_guard,
        output logic        r_round,
        output logic        r_sticky
    );
        logic        ovf;
        logic [5:0]  exp_norm;
        logic [7:0]  man_norm;
        logic [24:0] man_fp32;
        logic [7:0]  product_exp;
        logic [7:0]  shift_amount;

        ovf         = r_man_p[7];
        man_norm    = ovf ? (r_man_p >> 1) : r_man_p;
        exp_norm    = ovf ? ({1'b0, r_exp_p} + 6'd1) : {1'b0, r_exp_p};
        man_fp32    = {1'b0, man_norm[6:0], 17'b0};
        product_exp = exp_norm + 8'd120;

        if (r_acc_exp > product_exp) begin
            shift_amount = r_acc_exp - product_exp;
            r_common_exp = r_acc_exp;
        end else begin
            shift_amount = 8'd0;
            r_common_exp = product_exp;
        end

        calc_shift_grs(man_fp32, shift_amount, r_man_aligned,
                       r_guard, r_round, r_sticky);
    endtask

    task automatic ref_e5m2(
        input  logic [5:0]  r_exp_p,
        input  logic [5:0]  r_man_p,
        input  logic [7:0]  r_acc_exp,
        output logic [24:0] r_man_aligned,
        output logic [7:0]  r_common_exp,
        output logic        r_guard,
        output logic        r_round,
        output logic        r_sticky
    );
        logic        ovf;
        logic [6:0]  exp_norm;
        logic [5:0]  man_norm;
        logic [24:0] man_fp32;
        logic [7:0]  product_exp;
        logic [7:0]  shift_amount;

        ovf         = r_man_p[5];
        man_norm    = ovf ? (r_man_p >> 1) : r_man_p;
        exp_norm    = ovf ? ({1'b0, r_exp_p} + 7'd1) : {1'b0, r_exp_p};
        man_fp32    = {1'b0, man_norm[4:0], 19'b0};
        product_exp = exp_norm + 8'd112;

        if (r_acc_exp > product_exp) begin
            shift_amount = r_acc_exp - product_exp;
            r_common_exp = r_acc_exp;
        end else begin
            shift_amount = 8'd0;
            r_common_exp = product_exp;
        end

        calc_shift_grs(man_fp32, shift_amount, r_man_aligned,
                       r_guard, r_round, r_sticky);
    endtask

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

    // -------------------------------------------------------------------------
    // Compare helpers
    // -------------------------------------------------------------------------
    task automatic check_e4m3(input string label);
        logic [24:0] r_man;
        logic [7:0]  r_exp;
        logic        r_guard, r_round, r_sticky;

        ref_e4m3(exp4, man4, acc_exp4, r_man, r_exp, r_guard, r_round, r_sticky);
        if (man_aligned4 !== r_man || common_exp4 !== r_exp ||
            guard4 !== r_guard || round4 !== r_round || sticky4 !== r_sticky) begin
            $display("FAIL E4M3 [%-32s] exp_p=%05b man_p=%08b acc_exp=%0d | got man=%025b exp=%0d grs=%b%b%b | exp man=%025b exp=%0d grs=%b%b%b",
                     label, exp4, man4, acc_exp4,
                     man_aligned4, common_exp4, guard4, round4, sticky4,
                     r_man, r_exp, r_guard, r_round, r_sticky);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    task automatic check_e5m2(input string label);
        logic [24:0] r_man;
        logic [7:0]  r_exp;
        logic        r_guard, r_round, r_sticky;

        ref_e5m2(exp5, man5, acc_exp5, r_man, r_exp, r_guard, r_round, r_sticky);
        if (man_aligned5 !== r_man || common_exp5 !== r_exp ||
            guard5 !== r_guard || round5 !== r_round || sticky5 !== r_sticky) begin
            $display("FAIL E5M2 [%-32s] exp_p=%06b man_p=%06b acc_exp=%0d | got man=%025b exp=%0d grs=%b%b%b | exp man=%025b exp=%0d grs=%b%b%b",
                     label, exp5, man5, acc_exp5,
                     man_aligned5, common_exp5, guard5, round5, sticky5,
                     r_man, r_exp, r_guard, r_round, r_sticky);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // Hold the inactive DUT driven.
        exp5 = '0; man5 = '0; acc_exp5 = '0;

        // ======== E4M3 directed post-normalization and exponent cases ========
        exp4 = 5'd7;  man4 = 8'b0100_0000; acc_exp4 = 8'd127; #1; check_e4m3("min normalized, no shift");
        exp4 = 5'd7;  man4 = 8'b1000_0000; acc_exp4 = 8'd128; #1; check_e4m3("overflow normalize");
        exp4 = 5'd7;  man4 = 8'b1111_1111; acc_exp4 = 8'd128; #1; check_e4m3("max mantissa normalize");
        exp4 = 5'd0;  man4 = 8'b0100_0000; acc_exp4 = 8'd120; #1; check_e4m3("bias conversion exp zero");
        exp4 = 5'd23; man4 = 8'b0100_0000; acc_exp4 = 8'd143; #1; check_e4m3("bias conversion max exp");
        exp4 = 5'd31; man4 = 8'b1000_0000; acc_exp4 = 8'd153; #1; check_e4m3("exp headroom with overflow");
        exp4 = 5'd7;  man4 = 8'b0000_0000; acc_exp4 = 8'd160; #1; check_e4m3("zero product stays zero");

        // Product exponent larger than accumulator: product is not shifted.
        exp4 = 5'd8;  man4 = 8'b0100_0000; acc_exp4 = 8'd0;   #1; check_e4m3("product larger than acc");

        // ======== E4M3 G/R/S shift boundaries ===============================
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd127; #1; check_e4m3("shift 0");
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd128; #1; check_e4m3("shift 1");
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd129; #1; check_e4m3("shift 2");
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd130; #1; check_e4m3("shift 3");
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd151; #1; check_e4m3("shift 24 implicit to guard");
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd152; #1; check_e4m3("shift 25 implicit to round");
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd153; #1; check_e4m3("shift 26 implicit to sticky");
        exp4 = 5'd7;  man4 = 8'b0111_1111; acc_exp4 = 8'd154; #1; check_e4m3("shift 27 sticky only");

        // ======== E4M3 wide deterministic sweep =============================
        for (int e = 0; e < 32; e++) begin
            for (int m = 0; m < 256; m += 7) begin
                for (int a = 0; a < 256; a += 13) begin
                    exp4     = e[4:0];
                    man4     = m[7:0];
                    acc_exp4 = a[7:0];
                    #1;
                    check_e4m3($sformatf("sweep e=%0d m=%0d a=%0d", e, m, a));
                end
            end
        end

        // ======== E5M2 directed sanity cases =================================
        exp4 = '0; man4 = '0; acc_exp4 = '0;

        exp5 = 6'd15; man5 = 6'b010000; acc_exp5 = 8'd127; #1; check_e5m2("E5M2 no shift");
        exp5 = 6'd15; man5 = 6'b100000; acc_exp5 = 8'd128; #1; check_e5m2("E5M2 overflow normalize");
        exp5 = 6'd0;  man5 = 6'b010000; acc_exp5 = 8'd112; #1; check_e5m2("E5M2 bias conversion");
        exp5 = 6'd15; man5 = 6'b011111; acc_exp5 = 8'd151; #1; check_e5m2("E5M2 shift 24");
        exp5 = 6'd15; man5 = 6'b011111; acc_exp5 = 8'd154; #1; check_e5m2("E5M2 shift 27");

        for (int e = 0; e < 64; e += 3) begin
            for (int m = 0; m < 64; m += 5) begin
                for (int a = 0; a < 256; a += 29) begin
                    exp5     = e[5:0];
                    man5     = m[5:0];
                    acc_exp5 = a[7:0];
                    #1;
                    check_e5m2($sformatf("sweep e=%0d m=%0d a=%0d", e, m, a));
                end
            end
        end

        // ======== Summary ====================================================
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
