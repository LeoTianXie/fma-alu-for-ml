`timescale 1ns/1ps

module input_decode_tb;

    // -------------------------------------------------------------------------
    // DUT  (default E4M3 parameters: EXP_BITS=4, MAN_BITS=3)
    // -------------------------------------------------------------------------
    localparam int EXP_BITS = 4;
    localparam int MAN_BITS = 3;

    logic [EXP_BITS+MAN_BITS:0] raw_bits;  // [7:0]
    logic [1:0]                 fmt_sel;
    logic                       sign;
    logic [EXP_BITS-1:0]        exp;        // [3:0]
    logic [MAN_BITS:0]          mantissa;   // [3:0]  implicit 1 in bit[MAN_BITS]
    logic                       is_zero, is_inf, is_nan;

    input_decode #(.EXP_BITS(EXP_BITS), .MAN_BITS(MAN_BITS)) dut (.*);

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // Reference model — mirrors the RTL case logic exactly.
    //   All branch-local fields are hoisted to task scope for compatibility.
    // -------------------------------------------------------------------------
    task automatic ref_model(
        input  logic [7:0]  r_raw,
        input  logic [1:0]  r_fmt,
        output logic        r_sign,
        output logic [3:0]  r_exp,
        output logic [3:0]  r_man,
        output logic        r_zero,
        output logic        r_inf,
        output logic        r_nan
    );
        logic [1:0] e4;  logic       m1;   // FP4 fields
        logic [3:0] e8;  logic [2:0] m3;   // E4M3 fields
        logic [4:0] e5;  logic [1:0] m2;   // E5M2 fields

        r_sign = '0; r_exp = '0; r_man = '0;
        r_zero = '0; r_inf = '0; r_nan = '0;
        e4 = '0; m1 = '0; e8 = '0; m3 = '0; e5 = '0; m2 = '0;

        case (r_fmt)
            // FP4: 1 sign + 2 exp + 1 man packed in raw[3:0]
            2'b00: begin
                e4     = r_raw[2:1];
                m1     = r_raw[0];
                r_sign = r_raw[3];
                r_exp  = {2'b00, e4};           // zero-extend to EXP_BITS
                r_man  = {(e4 != 2'b00), m1, 2'b00};  // [3]=implicit, [2]=man, [1:0]=pad
                r_zero = (e4 == 2'b00) & (m1 == 1'b0);
                r_inf  = 1'b0;
                r_nan  = 1'b0;
            end

            // FP8 E4M3: 1 sign + 4 exp + 3 man.  No infinity encoding.
            2'b01: begin
                e8     = r_raw[6:3];
                m3     = r_raw[2:0];
                r_sign = r_raw[7];
                r_exp  = e8;
                r_man  = {(e8 != 4'h0), m3};   // [3]=implicit, [2:0]=man
                r_zero = (e8 == 4'h0) & (m3 == 3'h0);
                r_inf  = 1'b0;                  // E4M3 has no infinity
                r_nan  = (e8 == 4'hF);          // all-ones exp = NaN (any mantissa)
            end

            // FP8 E5M2: 1 sign + 5 exp + 2 man.
            // With EXP_BITS=4, exp[4] (MSB of e5) is truncated — expected behavior.
            2'b10: begin
                e5     = r_raw[6:2];
                m2     = r_raw[1:0];
                r_sign = r_raw[7];
                r_exp  = e5[3:0];               // truncate MSB to match EXP_BITS=4
                r_man  = {(e5 != 5'h00), 1'b0, m2};  // [3]=implicit, [2]=pad, [1:0]=man
                r_zero = (e5 == 5'h00) & (m2 == 2'h0);
                r_inf  = (e5 == 5'h1F) & (m2 == 2'h0);
                r_nan  = (e5 == 5'h1F) & (m2 != 2'h0);
            end

            // FP16 stub: only sign extracted; all other outputs stay 0.
            default: begin
                r_sign = r_raw[7];
            end
        endcase
    endtask

    // -------------------------------------------------------------------------
    // Compare helper
    // -------------------------------------------------------------------------
    task automatic check(input string label);
        logic       r_sign;
        logic [3:0] r_exp, r_man;
        logic       r_zero, r_inf, r_nan;
        ref_model(raw_bits, fmt_sel, r_sign, r_exp, r_man, r_zero, r_inf, r_nan);
        if (sign    !== r_sign || exp     !== r_exp  || mantissa !== r_man  ||
            is_zero !== r_zero || is_inf  !== r_inf  || is_nan   !== r_nan) begin
            $display(
                "FAIL [%-30s]  fmt=%02b raw=%08b | got  sign=%b exp=%04b man=%04b z=%b i=%b n=%b | exp sign=%b exp=%04b man=%04b z=%b i=%b n=%b",
                label, fmt_sel, raw_bits,
                sign, exp, mantissa, is_zero, is_inf, is_nan,
                r_sign, r_exp, r_man, r_zero, r_inf, r_nan);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin

        // ==== Exhaustive sweep: 4 formats × 256 raw_bits values = 1024 ======
        for (int f = 0; f < 4; f++) begin
            for (int r = 0; r < 256; r++) begin
                fmt_sel  = f[1:0];
                raw_bits = r[7:0];
                #1;
                check($sformatf("exhaust fmt=%02b raw=%02h", f, r));
            end
        end

        // ==== FP4 named cases (fmt_sel=00) ===================================
        // FP4 field layout in raw_bits[3:0]: {sign, exp[1:0], man[0]}

        fmt_sel = 2'b00;

        // ±zero: exp=00, man=0
        raw_bits = 8'h00; #1; check("FP4 +zero");
        raw_bits = 8'h08; #1; check("FP4 -zero (sign=1)");

        // Subnormal: exp=00, man=1  →  implicit bit = 0
        raw_bits = 8'h01; #1; check("FP4 +subnormal (exp=0 man=1)");
        raw_bits = 8'h09; #1; check("FP4 -subnormal");

        // Normal: exp=01, man=0  →  1.0 × 2^(1-bias)
        raw_bits = 8'h02; #1; check("FP4 +normal exp=01 man=0");

        // Normal: exp=10, man=1  →  1.1 × 2^(2-bias)
        raw_bits = 8'h05; #1; check("FP4 +normal exp=10 man=1");

        // Largest finite MX FP4 value: exp=11, man=1 -> 1.5 * 2^2 = 6.0
        raw_bits = 8'h07; #1; check("FP4 max finite 6.0");

        // MX FP4 has no inf/NaN encodings in this datapath.
        raw_bits = 8'h06; #1; check("FP4 finite exp=11 man=0");
        raw_bits = 8'h0E; #1; check("FP4 negative finite exp=11 man=0");

        raw_bits = 8'h07; #1; check("FP4 finite exp=11 man=1");

        // ==== FP8 E4M3 named cases (fmt_sel=01) ==============================
        // Field layout: {sign, exp[3:0], man[2:0]}

        fmt_sel = 2'b01;

        // ±zero
        raw_bits = 8'b0_0000_000; #1; check("E4M3 +zero");
        raw_bits = 8'b1_0000_000; #1; check("E4M3 -zero");

        // Subnormal: exp=0, man!=0  →  implicit bit = 0
        raw_bits = 8'b0_0000_001; #1; check("E4M3 +subnormal (man=001)");
        raw_bits = 8'b0_0000_111; #1; check("E4M3 +subnormal (man=111)");

        // Normal: exp=0001, man=000
        raw_bits = 8'b0_0001_000; #1; check("E4M3 +normal exp=1 man=0");

        // Normal midrange: exp=0111, man=111  →  1.111 × 2^0
        raw_bits = 8'b0_0111_111; #1; check("E4M3 +normal exp=7 man=7");

        // Max normal: exp=1110, man=111  (exp=1111 is NaN)
        raw_bits = 8'b0_1110_111; #1; check("E4M3 max normal");

        // Negative normal
        raw_bits = 8'b1_0111_011; #1; check("E4M3 -normal");

        // NaN: exp=1111, man=000  — NOT infinity in E4M3
        raw_bits = 8'b0_1111_000; #1; check("E4M3 nan (exp=F man=0, NOT inf)");
        raw_bits = 8'b0_1111_111; #1; check("E4M3 nan (exp=F man=7)");
        raw_bits = 8'b1_1111_001; #1; check("E4M3 -nan");

        // Confirm is_inf stays 0 and is_nan is 1 for all-ones exp
        raw_bits = 8'b0_1111_000; #1; check("E4M3 no-inf assertion");

        // ==== FP8 E5M2 named cases (fmt_sel=10) ==============================
        // Field layout: {sign, exp[4:0], man[1:0]}

        fmt_sel = 2'b10;

        // ±zero
        raw_bits = 8'b0_00000_00; #1; check("E5M2 +zero");
        raw_bits = 8'b1_00000_00; #1; check("E5M2 -zero");

        // Subnormal: exp=0, man!=0  →  implicit bit = 0
        raw_bits = 8'b0_00000_01; #1; check("E5M2 +subnormal (man=01)");
        raw_bits = 8'b0_00000_11; #1; check("E5M2 +subnormal (man=11)");

        // Normal: exp=00001, man=00
        raw_bits = 8'b0_00001_00; #1; check("E5M2 +normal exp=1");

        // Normal midrange: exp=01111, man=11  →  1.11 × 2^0
        raw_bits = 8'b0_01111_11; #1; check("E5M2 +normal exp=15 man=3");

        // Max normal: exp=11110, man=11
        raw_bits = 8'b0_11110_11; #1; check("E5M2 max normal");

        // ±inf: exp=11111, man=00
        raw_bits = 8'b0_11111_00; #1; check("E5M2 +inf");
        raw_bits = 8'b1_11111_00; #1; check("E5M2 -inf");

        // NaN: exp=11111, man!=0
        raw_bits = 8'b0_11111_01; #1; check("E5M2 nan (man=01)");
        raw_bits = 8'b0_11111_11; #1; check("E5M2 nan (man=11)");

        // Exponent MSB truncation (known EXP_BITS=4 limitation):
        //   e5 = 5'b10000 = 16 → exp output = 4'b0000 (MSB dropped)
        //   but implicit bit = 1 because e5 != 0
        raw_bits = 8'b0_10000_00; #1; check("E5M2 exp MSB truncation (e5=16->exp=0)");
        raw_bits = 8'b0_10001_10; #1; check("E5M2 exp MSB truncation (e5=17->exp=1)");

        // ==== FP16 stub (fmt_sel=11) =========================================
        // Only sign is extracted; exp/mantissa/flags all stay 0.

        fmt_sel = 2'b11;
        raw_bits = 8'b0_1111_111; #1; check("FP16 stub sign=0");
        raw_bits = 8'b1_1111_111; #1; check("FP16 stub sign=1");
        raw_bits = 8'b0_0000_000; #1; check("FP16 stub all-zero");

        // ==== Summary ========================================================
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
