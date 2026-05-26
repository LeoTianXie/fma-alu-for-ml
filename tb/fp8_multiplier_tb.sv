`timescale 1ns/1ps

module fp8_multiplier_tb;

    // -------------------------------------------------------------------------
    // E4M3 DUT (default parameters)
    // -------------------------------------------------------------------------
    localparam int EXP4 = 4;
    localparam int MAN3 = 3;

    logic [7:0]          a4, b4;
    logic                sign4;
    logic [EXP4:0]       exp4;      // 5 bits
    logic [2*MAN3+1:0]   man4;      // 8 bits

    fp8_multiplier #(.EXP_BITS(EXP4), .MAN_BITS(MAN3)) dut_e4m3 (
        .a      (a4),
        .b      (b4),
        .sign_p (sign4),
        .exp_p  (exp4),
        .man_p  (man4)
    );

    // -------------------------------------------------------------------------
    // E5M2 DUT (spot-check instance)
    // -------------------------------------------------------------------------
    localparam int EXP5 = 5;
    localparam int MAN2 = 2;

    logic [7:0]          a5, b5;
    logic                sign5;
    logic [EXP5:0]       exp5;      // 6 bits
    logic [2*MAN2+1:0]   man5;      // 6 bits

    fp8_multiplier #(.EXP_BITS(EXP5), .MAN_BITS(MAN2)) dut_e5m2 (
        .a      (a5),
        .b      (b5),
        .sign_p (sign5),
        .exp_p  (exp5),
        .man_p  (man5)
    );

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // E4M3 reference model  (bias = 7)
    //   man_a = {1, a[2:0]},  exp_a = a[6:3]
    // -------------------------------------------------------------------------
    task automatic ref_e4m3(
        input  logic [7:0]  in_a,
        input  logic [7:0]  in_b,
        output logic         r_sign,
        output logic [4:0]   r_exp,
        output logic [7:0]   r_man
    );
        logic [3:0] ea, eb, ma, mb;
        ea     = in_a[6:3];
        eb     = in_b[6:3];
        ma     = {1'b1, in_a[2:0]};
        mb     = {1'b1, in_b[2:0]};
        r_sign = in_a[7] ^ in_b[7];
        r_exp  = {1'b0, ea} + {1'b0, eb} - 5'd7;
        r_man  = {4'b0, ma} * {4'b0, mb};
    endtask

    // -------------------------------------------------------------------------
    // E5M2 reference model  (bias = 15)
    //   man_a = {1, a[1:0]},  exp_a = a[6:2]
    // -------------------------------------------------------------------------
    task automatic ref_e5m2(
        input  logic [7:0]  in_a,
        input  logic [7:0]  in_b,
        output logic         r_sign,
        output logic [5:0]   r_exp,
        output logic [5:0]   r_man
    );
        logic [4:0] ea, eb;
        logic [2:0] ma, mb;
        ea     = in_a[6:2];
        eb     = in_b[6:2];
        ma     = {1'b1, in_a[1:0]};
        mb     = {1'b1, in_b[1:0]};
        r_sign = in_a[7] ^ in_b[7];
        r_exp  = {1'b0, ea} + {1'b0, eb} - 6'd15;
        r_man  = {3'b0, ma} * {3'b0, mb};
    endtask

    // -------------------------------------------------------------------------
    // Compare helpers
    // -------------------------------------------------------------------------
    task automatic check_e4m3(input string label);
        logic        r_sign;
        logic [4:0]  r_exp;
        logic [7:0]  r_man;
        ref_e4m3(a4, b4, r_sign, r_exp, r_man);
        if (sign4 !== r_sign || exp4 !== r_exp || man4 !== r_man) begin
            $display("FAIL E4M3 [%-28s]  a=%08b b=%08b | got  sign=%b exp=%05b man=%08b | exp sign=%b exp=%05b man=%08b",
                     label, a4, b4, sign4, exp4, man4, r_sign, r_exp, r_man);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    task automatic check_e5m2(input string label);
        logic        r_sign;
        logic [5:0]  r_exp;
        logic [5:0]  r_man;
        ref_e5m2(a5, b5, r_sign, r_exp, r_man);
        if (sign5 !== r_sign || exp5 !== r_exp || man5 !== r_man) begin
            $display("FAIL E5M2 [%-28s]  a=%08b b=%08b | got  sign=%b exp=%06b man=%06b | exp sign=%b exp=%06b man=%06b",
                     label, a5, b5, sign5, exp5, man5, r_sign, r_exp, r_man);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin

        // ======== E4M3 — Exhaustive: all 65536 (a, b) pairs =================
        for (int i = 0; i < 256; i++) begin
            for (int j = 0; j < 256; j++) begin
                a4 = i[7:0];
                b4 = j[7:0];
                #1;
                check_e4m3($sformatf("exhaust[%02h][%02h]", i, j));
            end
        end

        // ======== E4M3 — Named targeted cases ================================

        // Sign combinations
        // a=b: sign=0, exp=1+1-7 wraps, man=9*9=81
        a4 = 8'b0_0001_001; b4 = 8'b0_0001_001; #1; check_e4m3("pos * pos => pos");
        a4 = 8'b1_0001_001; b4 = 8'b1_0001_001; #1; check_e4m3("neg * neg => pos");
        a4 = 8'b0_0001_001; b4 = 8'b1_0001_001; #1; check_e4m3("pos * neg => neg");
        a4 = 8'b1_0001_001; b4 = 8'b0_0001_001; #1; check_e4m3("neg * pos => neg");

        // Max exponent sum: 15+15-7 = 23 = 5'b10111 (no 5-bit overflow)
        a4 = 8'b0_1111_000; b4 = 8'b0_1111_000; #1; check_e4m3("max exp_p=23");

        // Exponent underflow: 0+0-7 wraps, MSB of exp_p set
        a4 = 8'b0_0000_001; b4 = 8'b0_0000_001; #1; check_e4m3("exp underflow wrap");

        // man_p[7]=1: 1.111 * 1.111 = 15*15 = 225 = 8'b1110_0001
        a4 = 8'b0_0001_111; b4 = 8'b0_0001_111; #1; check_e4m3("man_p msb set (15x15=225)");

        // man_p[7]=0: 1.000 * 1.000 = 8*8 = 64 = 8'b0100_0000
        a4 = 8'b0_0001_000; b4 = 8'b0_0001_000; #1; check_e4m3("man_p msb clear (8x8=64)");

        // Asymmetric exponents: 1+14-7 = 8
        a4 = 8'b0_0001_001; b4 = 8'b0_1110_010; #1; check_e4m3("asymmetric exponents");

        // Zero-like inputs (exp=0, man=0)
        a4 = 8'b0_0000_000; b4 = 8'b0_0101_011; #1; check_e4m3("zero-like a");
        a4 = 8'b0_0101_011; b4 = 8'b0_0000_000; #1; check_e4m3("zero-like b");
        a4 = 8'b0_0000_000; b4 = 8'b0_0000_000; #1; check_e4m3("both zero-like");

        // Inf/NaN passthrough (all-ones exponent)
        a4 = 8'b0_1111_111; b4 = 8'b0_0101_011; #1; check_e4m3("inf-like a");
        a4 = 8'b0_0101_011; b4 = 8'b0_1111_111; #1; check_e4m3("inf-like b");
        a4 = 8'b0_1111_111; b4 = 8'b0_1111_111; #1; check_e4m3("inf-like both");

        // ======== E5M2 — Spot checks (bias = 15) =============================

        // pos * pos, typical values
        a5 = 8'b0_00001_01; b5 = 8'b0_00001_01; #1; check_e5m2("pos * pos");
        a5 = 8'b1_00001_01; b5 = 8'b1_00001_01; #1; check_e5m2("neg * neg => pos");
        a5 = 8'b0_00001_01; b5 = 8'b1_00001_01; #1; check_e5m2("pos * neg");

        // Max exp sum: 31+31-15 = 47, needs 6-bit exp_p (5'b_11111 * 2 = 6 bits)
        a5 = 8'b0_11111_11; b5 = 8'b0_11111_11; #1; check_e5m2("max exp_p=47 and man");

        // Exp underflow: 0+0-15 wraps
        a5 = 8'b0_00000_01; b5 = 8'b0_00000_01; #1; check_e5m2("exp underflow wrap");

        // man_p MSB: 1.11*1.11 = 7*7=49 = 6'b110001, man5[5]=1
        a5 = 8'b0_00001_11; b5 = 8'b0_00001_11; #1; check_e5m2("man_p msb set (7x7=49)");

        // man_p MSB clear: 1.00*1.00 = 4*4=16 = 6'b010000, man5[5]=0
        a5 = 8'b0_00001_00; b5 = 8'b0_00001_00; #1; check_e5m2("man_p msb clear (4x4=16)");

        // Asymmetric exponents: 1+30-15 = 16
        a5 = 8'b0_00001_01; b5 = 8'b0_11110_10; #1; check_e5m2("asymmetric exponents");

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
