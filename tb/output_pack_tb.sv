`timescale 1ns/1ps

module output_pack_tb;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    logic        sign_in;
    logic [7:0]  exp_in;
    logic [22:0] man_in;
    logic [1:0]  fmt_out;
    logic [31:0] result;

    output_pack dut (.*);

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // Reference model — mirrors the RTL logic, including IEEE-style
    // all-ones exponent reservation for narrow formats.
    // -------------------------------------------------------------------------
    task automatic ref_model(
        input  logic        in_sign,
        input  logic [7:0]  in_exp,
        input  logic [22:0] in_man,
        input  logic [1:0]  in_fmt,
        output logic [31:0] r_result
    );
        logic signed [8:0] fp4_exp_s, e4m3_exp_s, e5m2_exp_s;
        logic              fp4_ovf, fp4_unf, e4m3_ovf, e4m3_unf, e5m2_ovf, e5m2_unf;

        fp4_exp_s  = {1'b0, in_exp} - 9'sd126;
        e4m3_exp_s = {1'b0, in_exp} - 9'sd120;
        e5m2_exp_s = {1'b0, in_exp} - 9'sd112;

        fp4_unf  = (fp4_exp_s  < 9'sd1);
        fp4_ovf  = (fp4_exp_s  > 9'sd2);
        e4m3_unf = (e4m3_exp_s < 9'sd1);
        e4m3_ovf = (e4m3_exp_s > 9'sd14);
        e5m2_unf = (e5m2_exp_s < 9'sd1);
        e5m2_ovf = (e5m2_exp_s > 9'sd30);

        r_result = 32'h0000_0000;

        case (in_fmt)
            2'b00: begin
                if (fp4_unf)
                    r_result[3:0] = {in_sign, 3'b000};
                else if (fp4_ovf)
                    r_result[3:0] = {in_sign, 2'b10, 1'b1};
                else
                    r_result[3:0] = {in_sign, fp4_exp_s[1:0], in_man[22]};
            end
            2'b01: begin
                if (e4m3_unf)
                    r_result[7:0] = {in_sign, 7'b000_0000};
                else if (e4m3_ovf)
                    r_result[7:0] = {in_sign, 4'b1110, 3'b111};
                else
                    r_result[7:0] = {in_sign, e4m3_exp_s[3:0], in_man[22:20]};
            end
            2'b10: begin
                if (e5m2_unf)
                    r_result[7:0] = {in_sign, 7'b000_0000};
                else if (e5m2_ovf)
                    r_result[7:0] = {in_sign, 5'b11110, 2'b11};
                else
                    r_result[7:0] = {in_sign, e5m2_exp_s[4:0], in_man[22:21]};
            end
            default: begin  // 2'b11 → FP32 passthrough
                r_result = {in_sign, in_exp, in_man};
            end
        endcase
    endtask

    // -------------------------------------------------------------------------
    // Compare helper
    // -------------------------------------------------------------------------
    task automatic check(input string label);
        logic [31:0] expected;
        ref_model(sign_in, exp_in, man_in, fmt_out, expected);
        if (result !== expected) begin
            $display("FAIL [%-44s] fmt=%02b sign=%b exp=%03d man=%07h | got %08h | exp %08h",
                     label, fmt_out, sign_in, exp_in, man_in, result, expected);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin

        // ==== FP32 passthrough (fmt_out = 2'b11) ============================
        fmt_out = 2'b11;

        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h500000; #1; check("FP32 +1.625");
        sign_in = 1'b1; exp_in = 8'd127; man_in = 23'h500000; #1; check("FP32 -1.625");
        sign_in = 1'b0; exp_in = 8'd0;   man_in = 23'h000000; #1; check("FP32 +0");
        sign_in = 1'b1; exp_in = 8'd0;   man_in = 23'h000000; #1; check("FP32 -0");
        sign_in = 1'b0; exp_in = 8'd255; man_in = 23'h000000; #1; check("FP32 +inf");
        sign_in = 1'b0; exp_in = 8'd255; man_in = 23'h400000; #1; check("FP32 NaN");
        sign_in = 1'b0; exp_in = 8'd128; man_in = 23'h7FFFFF; #1; check("FP32 max-frac");

        // ==== E4M3 (fmt_out = 2'b01) ========================================
        fmt_out = 2'b01;

        // Bias diff = 120. In-range: exp_in ∈ [121, 134].
        sign_in = 1'b0; exp_in = 8'd119; man_in = 23'h7FFFFF; #1; check("E4M3 underflow exp_in=119");
        sign_in = 1'b0; exp_in = 8'd120; man_in = 23'h7FFFFF; #1; check("E4M3 underflow boundary 120");
        sign_in = 1'b0; exp_in = 8'd121; man_in = 23'h500000; #1; check("E4M3 min in-range exp_s=1");
        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h500000; #1; check("E4M3 mid in-range exp_s=7");
        sign_in = 1'b0; exp_in = 8'd134; man_in = 23'hE00000; #1; check("E4M3 max in-range exp_s=14");
        sign_in = 1'b0; exp_in = 8'd135; man_in = 23'h000000; #1; check("E4M3 overflow boundary 135");
        sign_in = 1'b0; exp_in = 8'd200; man_in = 23'h000000; #1; check("E4M3 overflow exp_in=200");
        sign_in = 1'b0; exp_in = 8'd255; man_in = 23'h000000; #1; check("E4M3 overflow at FP32 inf exp");

        // Sign propagation through overflow / underflow
        sign_in = 1'b1; exp_in = 8'd200; man_in = 23'h000000; #1; check("E4M3 neg overflow");
        sign_in = 1'b1; exp_in = 8'd100; man_in = 23'h7FFFFF; #1; check("E4M3 neg underflow");

        // Mantissa truncation
        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h7FFFFF; #1; check("E4M3 max man truncates to 111");
        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h0FFFFF; #1; check("E4M3 man[22:20] all-zero pick");

        // ==== E5M2 (fmt_out = 2'b10) ========================================
        fmt_out = 2'b10;

        // Bias diff = 112. In-range: exp_in ∈ [113, 142].
        sign_in = 1'b0; exp_in = 8'd111; man_in = 23'h7FFFFF; #1; check("E5M2 underflow exp_in=111");
        sign_in = 1'b0; exp_in = 8'd112; man_in = 23'h7FFFFF; #1; check("E5M2 underflow boundary 112");
        sign_in = 1'b0; exp_in = 8'd113; man_in = 23'h400000; #1; check("E5M2 min in-range exp_s=1");
        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h400000; #1; check("E5M2 mid in-range exp_s=15");
        sign_in = 1'b0; exp_in = 8'd142; man_in = 23'h600000; #1; check("E5M2 max in-range exp_s=30");
        sign_in = 1'b0; exp_in = 8'd143; man_in = 23'h000000; #1; check("E5M2 overflow boundary 143");
        sign_in = 1'b0; exp_in = 8'd200; man_in = 23'h000000; #1; check("E5M2 overflow exp_in=200");
        sign_in = 1'b1; exp_in = 8'd200; man_in = 23'h000000; #1; check("E5M2 neg overflow");
        sign_in = 1'b1; exp_in = 8'd100; man_in = 23'h7FFFFF; #1; check("E5M2 neg underflow");

        // ==== FP4 (fmt_out = 2'b00) — includes the just-fixed boundary =====
        fmt_out = 2'b00;

        // Bias diff = 126. In-range: exp_in ∈ [127, 128] after the fix.
        sign_in = 1'b0; exp_in = 8'd125; man_in = 23'h7FFFFF; #1; check("FP4 underflow exp_in=125");
        sign_in = 1'b0; exp_in = 8'd126; man_in = 23'h7FFFFF; #1; check("FP4 underflow boundary 126");
        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h400000; #1; check("FP4 min in-range exp_s=1");
        sign_in = 1'b0; exp_in = 8'd128; man_in = 23'h400000; #1; check("FP4 max in-range exp_s=2");

        // The regression cases — these were the bug
        sign_in = 1'b0; exp_in = 8'd129; man_in = 23'h400000; #1; check("FP4 overflow boundary exp_in=129 (bugfix)");
        sign_in = 1'b0; exp_in = 8'd130; man_in = 23'h400000; #1; check("FP4 overflow exp_in=130");
        sign_in = 1'b0; exp_in = 8'd200; man_in = 23'h000000; #1; check("FP4 overflow exp_in=200");

        // Sign propagation across all FP4 paths
        sign_in = 1'b1; exp_in = 8'd200; man_in = 23'h000000; #1; check("FP4 neg overflow");
        sign_in = 1'b1; exp_in = 8'd100; man_in = 23'h7FFFFF; #1; check("FP4 neg underflow");
        sign_in = 1'b1; exp_in = 8'd128; man_in = 23'h000000; #1; check("FP4 neg in-range max");

        // Mantissa MSB only matters via in_man[22]
        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h7FFFFF; #1; check("FP4 man[22]=1");
        sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h3FFFFF; #1; check("FP4 man[22]=0 (high bit clear)");

        // ==== Upper-bits-zero contract — re-check after switching fmt_out ===
        // Pre-poison result by running FP32 passthrough first, then narrow.
        fmt_out = 2'b11; sign_in = 1'b1; exp_in = 8'hFF; man_in = 23'h7FFFFF; #1; check("poison FP32");
        fmt_out = 2'b01; sign_in = 1'b0; exp_in = 8'd121; man_in = 23'h000000; #1;
        check("E4M3 after FP32 poison (upper bits)");
        fmt_out = 2'b10; sign_in = 1'b0; exp_in = 8'd113; man_in = 23'h000000; #1;
        check("E5M2 after FP32 poison");
        fmt_out = 2'b00; sign_in = 1'b0; exp_in = 8'd127; man_in = 23'h000000; #1;
        check("FP4 after FP32 poison");

        // ==== Random sweep ==================================================
        for (int i = 0; i < 5000; i++) begin
            sign_in = $random;
            exp_in  = $random;
            man_in  = $random;
            fmt_out = $random;
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
