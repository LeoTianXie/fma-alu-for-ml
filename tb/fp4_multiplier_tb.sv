`timescale 1ns/1ps

module fp4_multiplier_tb;

    // -------------------------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------------------------
    logic [3:0] a, b;
    logic       sign_p;
    logic [2:0] exp_p;
    logic [3:0] man_p;

    fp4_multiplier dut (.*);

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // Reference model
    //   Mirrors the RTL arithmetic exactly so the testbench is independent.
    //   Man multiply uses explicit zero-extension to avoid width ambiguity.
    // -------------------------------------------------------------------------
    task automatic ref_model(
        input  logic [3:0] in_a,
        input  logic [3:0] in_b,
        output logic        r_sign,
        output logic [2:0]  r_exp,
        output logic [3:0]  r_man
    );
        logic [1:0] ea, eb, ma, mb;
        ea     = in_a[2:1];
        eb     = in_b[2:1];
        ma     = {|in_a[2:1], in_a[0]};   // implicit bit = 0 when exp=0 (subnormal/zero)
        mb     = {|in_b[2:1], in_b[0]};
        r_sign = in_a[3] ^ in_b[3];
        r_man  = {2'b0, ma} * {2'b0, mb};   // 4-bit context, no truncation
        r_exp  = {1'b0, ea} + {1'b0, eb} - 3'd1;  // bias = 1
    endtask

    // -------------------------------------------------------------------------
    // Compare helper — call after applying stimuli and waiting #1
    // -------------------------------------------------------------------------
    task automatic check(input string label);
        logic        r_sign;
        logic [2:0]  r_exp;
        logic [3:0]  r_man;
        ref_model(a, b, r_sign, r_exp, r_man);
        if (sign_p !== r_sign || exp_p !== r_exp || man_p !== r_man) begin
            $display("FAIL [%-28s]  a=%04b b=%04b | got  sign=%b exp=%03b man=%04b | exp sign=%b exp=%03b man=%04b",
                     label, a, b, sign_p, exp_p, man_p, r_sign, r_exp, r_man);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // ---- Exhaustive sweep: all 256 (a, b) pairs --------------------------
        // This fully verifies the combinational logic for every input encoding.
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                a = i[3:0];
                b = j[3:0];
                #1;
                check($sformatf("exhaust[%01h][%01h]", i, j));
            end
        end

        // ---- Named targeted cases --------------------------------------------

        // Sign combinations
        a = 4'b0011; b = 4'b0011; #1; check("pos * pos => pos");
        a = 4'b1011; b = 4'b1011; #1; check("neg * neg => pos");
        a = 4'b0011; b = 4'b1011; #1; check("pos * neg => neg");
        a = 4'b1011; b = 4'b0011; #1; check("neg * pos => neg");

        // Max mantissa product: man_a=11, man_b=11 => 1001 (man_p[3]=1)
        // Caller must post-normalize when man_p[3] is set.
        a = 4'b0011; b = 4'b0011; #1; check("man_msb_set (3x3=9)");

        // Min mantissa product: man_a=10, man_b=10 => 0100 (man_p[3]=0)
        a = 4'b0010; b = 4'b0010; #1; check("man_msb_clear (2x2=4)");

        // Max exponent sum: 3+3-1 = 5 (no 3-bit overflow)
        a = 4'b0110; b = 4'b0110; #1; check("max exp_p=5");

        // Max mantissa AND exponent: exp_p=5, man_p=1001
        a = 4'b0111; b = 4'b0111; #1; check("max exp and man");

        // Exponent underflow: 0+0-1 wraps to 3'b111 (7 unsigned).
        // Caller gates on is_zero from input_decode, so this value is never used.
        a = 4'b0001; b = 4'b0001; #1; check("exp underflow wrap (0+0-1)");

        // Asymmetric exponents: 0+3-1 = 2
        a = 4'b0001; b = 4'b0111; #1; check("asymmetric exp (0+3-1=2)");
        a = 4'b0111; b = 4'b0001; #1; check("asymmetric exp reversed");

        // Zero-like inputs (exp=00, man=0 → subnormal/zero encoding).
        // The multiplier runs the arithmetic; caller uses is_zero to mask.
        a = 4'b0000; b = 4'b0101; #1; check("zero-like a, normal b");
        a = 4'b0101; b = 4'b0000; #1; check("normal a, zero-like b");
        a = 4'b0000; b = 4'b0000; #1; check("both zero-like");

        // All-ones exponent (inf/NaN encoding per FP4 variant).
        // Arithmetic passthrough; special handling is in the caller.
        a = 4'b0111; b = 4'b0101; #1; check("inf-like a");
        a = 4'b0101; b = 4'b0111; #1; check("inf-like b");
        a = 4'b0111; b = 4'b0111; #1; check("inf-like a and b");

        // ---- Summary --------------------------------------------------------
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
