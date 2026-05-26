`timescale 1ns/1ps

module normalizer_tb;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    logic        sign_in;
    logic [7:0]  exp_in;
    logic [24:0] man_in;
    logic        guard_bit;
    logic        round_bit;
    logic        sticky_bit;
    logic        sign_out;
    logic [7:0]  exp_out;
    logic [22:0] man_out;
    logic        overflow;
    logic        underflow;

    normalizer dut (.*);

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // Reference model — mirrors the 5-stage RTL pipeline.
    // -------------------------------------------------------------------------
    task automatic ref_model(
        input  logic        in_sign,
        input  logic [7:0]  in_exp,
        input  logic [24:0] in_man,
        input  logic        in_G,
        input  logic        in_R,
        input  logic        in_S,
        output logic        r_sign,
        output logic [7:0]  r_exp,
        output logic [22:0] r_man,
        output logic        r_overflow,
        output logic        r_underflow
    );
        logic signed [9:0] pre_exp;
        logic signed [9:0] norm_exp;
        logic signed [9:0] final_exp;
        logic [23:0]       pre_man;
        logic              pre_G;
        logic              pre_R;
        logic              pre_S;
        logic [4:0]        lz;
        logic [26:0]       extended;
        logic [26:0]       shifted;
        logic [23:0]       norm_man;
        logic              norm_G;
        logic              norm_R;
        logic              norm_S;
        logic              round_up;
        logic [24:0]       rounded;
        logic [23:0]       final_man;
        logic              is_zero;

        // Stage 1: pre-normalize bit-24 carry
        if (in_man[24]) begin
            pre_man = in_man[24:1];
            pre_G   = in_man[0];
            pre_R   = in_G;
            pre_S   = in_R | in_S;
            pre_exp = {2'b00, in_exp} + 10'sd1;
        end else begin
            pre_man = in_man[23:0];
            pre_G   = in_G;
            pre_R   = in_R;
            pre_S   = in_S;
            pre_exp = {2'b00, in_exp};
        end

        // Stage 2: leading-zero count
        lz = 5'd24;
        for (int i = 23; i >= 0; i--) begin
            if (pre_man[i]) begin
                lz = 5'(23 - i);
                break;
            end
        end

        // Stage 3: left-shift normalize
        extended = {pre_man, pre_G, pre_R, pre_S};
        shifted  = extended << lz;
        norm_man = shifted[26:3];
        norm_G   = shifted[2];
        norm_R   = shifted[1];
        norm_S   = shifted[0] | (pre_S & (lz >= 5'd4));
        norm_exp = pre_exp - {5'b00000, lz};

        // Stage 4: round-to-nearest-even
        round_up = norm_G & (norm_R | norm_S | norm_man[0]);
        rounded  = {1'b0, norm_man} + {24'b0, round_up};

        // Stage 4b: post-rounding renormalize
        if (rounded[24]) begin
            final_man = rounded[24:1];
            final_exp = norm_exp + 10'sd1;
        end else begin
            final_man = rounded[23:0];
            final_exp = norm_exp;
        end

        // Stage 5: output assembly
        is_zero = (pre_man == 24'b0) & ~pre_G & ~pre_R & ~pre_S;

        r_sign      = in_sign;
        r_exp       = 8'h00;
        r_man       = 23'h0;
        r_overflow  = 1'b0;
        r_underflow = 1'b0;

        if (is_zero) begin
            r_exp = 8'h00;
            r_man = 23'h0;
        end else if (final_exp >= 10'sd255) begin
            r_exp      = 8'hFF;
            r_man      = 23'h0;
            r_overflow = 1'b1;
        end else if (final_exp <= 10'sd0) begin
            r_exp       = 8'h00;
            r_man       = 23'h0;
            r_underflow = (final_man != 24'b0);
        end else begin
            r_exp = final_exp[7:0];
            r_man = final_man[22:0];
        end
    endtask

    // -------------------------------------------------------------------------
    // Compare helper
    // -------------------------------------------------------------------------
    task automatic check(input string label);
        logic        r_sign;
        logic [7:0]  r_exp;
        logic [22:0] r_man;
        logic        r_overflow;
        logic        r_underflow;

        ref_model(sign_in, exp_in, man_in, guard_bit, round_bit, sticky_bit,
                  r_sign, r_exp, r_man, r_overflow, r_underflow);

        if (sign_out !== r_sign || exp_out !== r_exp || man_out !== r_man ||
            overflow !== r_overflow || underflow !== r_underflow) begin
            $display("FAIL [%-40s] man=%025b exp=%0d grs=%b%b%b | got s=%b e=%0d m=%023b of=%b uf=%b | exp s=%b e=%0d m=%023b of=%b uf=%b",
                     label, man_in, exp_in, guard_bit, round_bit, sticky_bit,
                     sign_out, exp_out, man_out, overflow, underflow,
                     r_sign, r_exp, r_man, r_overflow, r_underflow);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin

        // ==== Stage-by-stage directed cases =================================

        // --- Stage 1: bit-24 carry slot handling ---
        sign_in = 1'b0; exp_in = 8'd127; guard_bit = 1'b0; round_bit = 1'b0; sticky_bit = 1'b0;

        man_in = 25'h0_800000; #1; check("normalized 1.0, no rounding");
        man_in = 25'h0_FFFFFF; #1; check("normalized max mantissa");
        man_in = 25'h1_000000; #1; check("bit-24 carry, clean");

        man_in = 25'h1_000001; guard_bit = 1'b1; round_bit = 1'b1; sticky_bit = 1'b1; #1;
        check("bit-24 carry with GRS folding");
        guard_bit = 1'b0; round_bit = 1'b0; sticky_bit = 1'b0;

        // --- Stage 2: LZ count boundaries ---
        man_in = 25'h0_400000; #1; check("LZ=1");
        man_in = 25'h0_200000; #1; check("LZ=2");
        man_in = 25'h0_100000; #1; check("LZ=3");
        man_in = 25'h0_080000; #1; check("LZ=4 (sticky OR-back threshold)");
        man_in = 25'h0_000400; #1; check("LZ=13 (mid range)");
        man_in = 25'h0_000001; #1; check("LZ=23 (max meaningful)");

        // --- Zero handling ---
        man_in = 25'h0_000000; #1; check("all-zero input (is_zero path)");

        // pre_man=0 but G/R/S set → LZ=24 path with subnormal-like residue
        man_in = 25'h0_000000; guard_bit = 1'b1; round_bit = 1'b0; sticky_bit = 1'b0; #1;
        check("pre_man=0 with G=1");
        guard_bit = 1'b0;

        man_in = 25'h0_000000; sticky_bit = 1'b1; #1;
        check("pre_man=0 with S=1");
        sticky_bit = 1'b0;

        // --- Stage 4: rounding rules ---
        man_in = 25'h0_800000; guard_bit = 1'b0;                                  #1; check("RNE: G=0 no round");
        man_in = 25'h0_800000; guard_bit = 1'b1; round_bit = 1'b1;                #1; check("RNE: round up via R");
        man_in = 25'h0_800000; guard_bit = 1'b1; round_bit = 1'b0; sticky_bit = 1'b1; #1;
        check("RNE: round up via S");
        guard_bit = 1'b0; round_bit = 1'b0; sticky_bit = 1'b0;

        // Half-to-even cases (G=1, R=0, S=0)
        man_in = 25'h0_800002; guard_bit = 1'b1; #1; check("RNE half-to-even (LSB=0, hold)");
        man_in = 25'h0_800003; guard_bit = 1'b1; #1; check("RNE half-to-even (LSB=1, round up)");
        guard_bit = 1'b0;

        // --- Stage 4b: rounding overflows mantissa ---
        man_in = 25'h0_FFFFFF; guard_bit = 1'b1; round_bit = 1'b1; #1;
        check("round-up overflows mantissa to 2.0");
        guard_bit = 1'b0; round_bit = 1'b0;

        // --- Stage 5: overflow / underflow flags ---
        exp_in = 8'd254; man_in = 25'h1_000000; #1; check("exp overflow via carry slot");
        exp_in = 8'd254; man_in = 25'h0_FFFFFF; guard_bit = 1'b1; round_bit = 1'b1; #1;
        check("exp overflow via rounding bump");
        guard_bit = 1'b0; round_bit = 1'b0;

        exp_in = 8'd1; man_in = 25'h0_000010; #1; check("exp underflow (LZ=19, exp goes neg)");
        exp_in = 8'd5; man_in = 25'h0_000001; #1; check("exp underflow (LZ=23, exp=-18)");

        // Sign passthrough
        exp_in = 8'd127; sign_in = 1'b1; man_in = 25'h0_800000; #1;
        check("negative sign propagates");
        sign_in = 1'b0;

        // --- Bit-24 carry combined with rounding bump (chained exp +1 +1) ---
        exp_in = 8'd200; man_in = 25'h1_FFFFFF; guard_bit = 1'b1; round_bit = 1'b1; #1;
        check("bit-24 carry plus rounding bump (exp +1 +1)");
        guard_bit = 1'b0; round_bit = 1'b0;

        // --- LZ=4 sticky OR-back exercised (G must be 0 in output, so behaviour is inert
        //     but reference and DUT must still agree) ---
        exp_in = 8'd127; man_in = 25'h0_080000; sticky_bit = 1'b1; #1;
        check("LZ=4 with pre_S=1 (OR-back path)");
        sticky_bit = 1'b0;

        // ==== Random sweep ==================================================
        for (int i = 0; i < 10000; i++) begin
            sign_in    = $random;
            exp_in     = $random;
            man_in     = $random;
            guard_bit  = $random;
            round_bit  = $random;
            sticky_bit = $random;
            #1;
            check($sformatf("random[%0d]", i));
        end

        // ==== Summary =======================================================
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
