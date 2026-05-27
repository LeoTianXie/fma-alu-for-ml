// =====================================================================
// fma_vector_unit_mx_tb.sv
//
// OCP-MX-style reference testbench for fma_vector_unit.
//
// Methodology (OCP Microscaling Formats v1.0, Section 6.1):
//   The dot product of two MX-compliant vectors A,B of length k is:
//       C = X^A * X^B * SUM_{i=1..k} ( P_i^A * P_i^B )
//
//   The fma_vector_unit DUT does NOT consume an explicit block scale;
//   it is equivalent to an MX configuration with both block scales pinned
//   to X = 2^0 = 1.0 (i.e. E8M0 raw = 8'd127). The reference therefore
//   reduces to a plain dot product over the decoded element values, with
//   the running sum seeded by acc_seed (FP32).
//
// Oracle precision:
//   We compute the reference in SystemVerilog `real` (IEEE 754 double)
//   per Section 6.1's "internal precision of the dot product ... is
//   implementation-defined". Double precision is several orders of
//   magnitude wider than the DUT's FP32 accumulator, so any numerical
//   deviation that exceeds ~1 FP32 ulp implicates the DUT, not the ref.
//
// What this exposes vs the original self-checking TB:
//   - Long same-sign accumulation regressions in fp32_accumulator
//   - FP4 edge cases in the format-correct multiplier/alignment path
//   - Conservative sticky OR-back in normalizer (rounding bias)
//   - Output_pack truncation when narrowing (not exercised here, fmt=11)
//
// Element decode follows OCP MX v1.0 Section 5.3:
//   - E4M3:   bias=7,  m=3, no Inf (all-1s exp = NaN)
//   - E5M2:   bias=15, m=2, has Inf/NaN
//   - E2M1:   bias=1,  m=1, no Inf/NaN, subnormals supported
//
//   For normal: v = (-1)^S * 2^(E-bias) * (1 + M*2^-m)
//   For subnorm (E==0): v = (-1)^S * 2^(1-bias) * (M*2^-m)
// =====================================================================

`timescale 1ns/1ps

module fma_vector_unit_mx_tb;

    localparam int VECTOR_LEN = 16;
    localparam int EXP_BITS   = 4;
    localparam int MAN_BITS   = 3;

    // fmt_sel encoding (matches input_decode.sv)
    localparam logic [1:0] FMT_FP4   = 2'b00;
    localparam logic [1:0] FMT_E4M3  = 2'b01;
    localparam logic [1:0] FMT_E5M2  = 2'b10;
    localparam logic [1:0] FMT_FP32  = 2'b11;

    logic                       clk;
    logic                       rst;
    logic [1:0]                 fmt_sel;
    logic [1:0]                 fmt_out;
    logic [VECTOR_LEN-1:0][7:0] operand_a;
    logic [VECTOR_LEN-1:0][7:0] operand_b;
    logic [31:0]                acc_seed;
    logic [31:0]                result;
    logic                       overflow;
    logic                       underflow;
    logic                       valid_out;

    int   pass_count;
    int   fail_count;

    fma_vector_unit #(
        .VECTOR_LEN (VECTOR_LEN),
        .EXP_BITS   (EXP_BITS),
        .MAN_BITS   (MAN_BITS)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .fmt_sel   (fmt_sel),
        .fmt_out   (fmt_out),
        .operand_a (operand_a),
        .operand_b (operand_b),
        .acc_seed  (acc_seed),
        .result    (result),
        .overflow  (overflow),
        .underflow (underflow),
        .valid_out (valid_out)
    );

    // 10ns clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------
    // Decode helpers: raw bits -> real (OCP MX v1.0 Section 5.3)
    // -----------------------------------------------------------------
    function automatic real decode_e4m3(input logic [7:0] b);
        logic        s;
        logic [3:0]  e;
        logic [2:0]  m;
        real         v;
        begin
            s = b[7]; e = b[6:3]; m = b[2:0];
            if (e == 4'hF && m == 3'b111) begin
                // Per OCP MX v1.0 Table 2: only S 1111 111 is NaN.
                // 0_1111_110 = +/-448 is the max normal.
                v = 0.0/0.0;
            end else if (e == 4'h0 && m == 3'b000) begin
                v = 0.0;
            end else if (e == 4'h0) begin
                // subnormal: 2^(1-7) * (m/8)
                v = (2.0**(1-7)) * (real'(m) / 8.0);
            end else begin
                // normal:   2^(e-7)  * (1 + m/8)
                v = (2.0**(int'(e)-7)) * (1.0 + real'(m)/8.0);
            end
            return s ? -v : v;
        end
    endfunction

    function automatic real decode_e5m2(input logic [7:0] b);
        logic        s;
        logic [4:0]  e;
        logic [1:0]  m;
        real         v;
        begin
            s = b[7]; e = b[6:2]; m = b[1:0];
            if (e == 5'h1F && m == 2'b00) begin
                v = s ? -1.0/0.0 : 1.0/0.0;       // +/-Inf
            end else if (e == 5'h1F) begin
                v = 0.0/0.0;                       // NaN
            end else if (e == 5'h00 && m == 2'b00) begin
                v = 0.0;
            end else if (e == 5'h00) begin
                v = (2.0**(1-15)) * (real'(m) / 4.0);
            end else begin
                v = (2.0**(int'(e)-15)) * (1.0 + real'(m)/4.0);
            end
            return s ? -v : v;
        end
    endfunction

    // E2M1 (FP4): low nibble of an 8-bit operand carries {S,E1,E0,M}
    function automatic real decode_fp4(input logic [7:0] b);
        logic        s;
        logic [1:0]  e;
        logic        m;
        real         v;
        begin
            s = b[3]; e = b[2:1]; m = b[0];
            if (e == 2'b00 && m == 1'b0) begin
                v = 0.0;
            end else if (e == 2'b00) begin
                v = (2.0**(1-1)) * (real'(m) / 2.0);   // = 0.5
            end else begin
                v = (2.0**(int'(e)-1)) * (1.0 + real'(m)/2.0);
            end
            return s ? -v : v;
        end
    endfunction

    function automatic real decode_elem(input logic [1:0] fmt, input logic [7:0] b);
        case (fmt)
            FMT_FP4:  return decode_fp4(b);
            FMT_E4M3: return decode_e4m3(b);
            FMT_E5M2: return decode_e5m2(b);
            default:  return 0.0;
        endcase
    endfunction

    // FP32 bit pattern -> real (oracle side; for acc_seed and result compare)
    function automatic real fp32_to_real(input logic [31:0] b);
        logic        s;
        logic [7:0]  e;
        logic [22:0] m;
        real         v;
        begin
            s = b[31]; e = b[30:23]; m = b[22:0];
            if (e == 8'hFF && m == 0) begin
                v = s ? -1.0/0.0 : 1.0/0.0;
            end else if (e == 8'hFF) begin
                v = 0.0/0.0;
            end else if (e == 8'h00 && m == 0) begin
                v = 0.0;
            end else if (e == 8'h00) begin
                v = (2.0**(1-127)) * (real'(m) / (2.0**23));
            end else begin
                v = (2.0**(int'(e)-127)) * (1.0 + real'(m)/(2.0**23));
            end
            return s ? -v : v;
        end
    endfunction

    // -----------------------------------------------------------------
    // Oracle: OCP-MX dot product with implicit X^A = X^B = 1
    //         C = seed + sum_i ( decode(A_i) * decode(B_i) )
    // -----------------------------------------------------------------
    function automatic real mx_ref_dot(
        input logic [1:0]                 fmt,
        input logic [VECTOR_LEN-1:0][7:0] a,
        input logic [VECTOR_LEN-1:0][7:0] b,
        input logic [31:0]                seed
    );
        real acc;
        int  i;
        begin
            acc = fp32_to_real(seed);
            for (i = 0; i < VECTOR_LEN; i++) begin
                acc = acc + decode_elem(fmt, a[i]) * decode_elem(fmt, b[i]);
            end
            return acc;
        end
    endfunction

    // -----------------------------------------------------------------
    // Tolerance check.  Bit-exact would only pass on a fully-IEEE DUT;
    // we allow N FP32 ulps. We also accept relative error for large
    // magnitudes (where ulp dominates) and absolute error for tiny ones.
    //   ulp(x) ~ 2^(floor(log2|x|) - 23)
    // -----------------------------------------------------------------
    function automatic real fp32_ulp(input real x);
        real ax;
        int  e;
        begin
            ax = (x < 0) ? -x : x;
            if (ax == 0.0) return 2.0**(-149);   // smallest subnormal
            e  = $floor($ln(ax)/$ln(2.0));
            return 2.0**(e - 23);
        end
    endfunction

    // Half-ulp of the narrow output format at magnitude x. The DUT round-trips
    // the FP32 result back to the input format, so even a perfect arithmetic
    // pipeline can deviate by up to half a narrow-format ulp.
    function automatic real narrow_half_ulp(input logic [1:0] fmt, input real x);
        real ax;
        int  e;
        int  m_bits;
        begin
            ax = (x < 0) ? -x : x;
            case (fmt)
                FMT_FP4:  m_bits = 1;
                FMT_E4M3: m_bits = 3;
                FMT_E5M2: m_bits = 2;
                default:  m_bits = 23;
            endcase
            if (ax == 0.0) return 0.0;
            e = $floor($ln(ax)/$ln(2.0));
            return 0.5 * (2.0**(e - m_bits));
        end
    endfunction

    // Decode the DUT result. output_pack packs the result back into the
    // same narrow format as the inputs (fmt_sel drives both), so we must
    // decode with the matching format. Only fmt_sel=2'b11 is FP32 passthrough.
    function automatic real decode_result(input logic [1:0] fmt, input logic [31:0] r);
        case (fmt)
            FMT_FP4:  return decode_fp4 (r[7:0]);
            FMT_E4M3: return decode_e4m3(r[7:0]);
            FMT_E5M2: return decode_e5m2(r[7:0]);
            default:  return fp32_to_real(r);
        endcase
    endfunction

    task automatic check_result(
        input string name,
        input real   ref_val,
        input int    ulp_tol
    );
        real dut_val;
        real diff;
        real tol;
        real ulp_err;
        begin
            dut_val = decode_result(fmt_out, result);
            diff    = dut_val - ref_val;
            if (diff < 0) diff = -diff;
            // Output is FP32 passthrough, so tolerance is purely FP32-ulp-based.
            tol     = real'(ulp_tol) * fp32_ulp(ref_val);
            ulp_err = (fp32_ulp(ref_val) > 0) ? diff / fp32_ulp(ref_val) : 0.0;

            if (diff <= tol) begin
                $display("[PASS] %-40s ref=%.6e dut=%.6e  ulp_err=%0.2f",
                         name, ref_val, dut_val, ulp_err);
                pass_count++;
            end else begin
                $display("[FAIL] %-40s ref=%.6e dut=%.6e  diff=%.3e  tol=%.3e  ulp_err=%0.1f",
                         name, ref_val, dut_val, diff, tol, ulp_err);
                fail_count++;
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Single DUT run: issue rst, drive inputs, wait for valid_out
    // -----------------------------------------------------------------
    task automatic run_dot(
        input logic [1:0]                 fmt,
        input logic [VECTOR_LEN-1:0][7:0] a,
        input logic [VECTOR_LEN-1:0][7:0] b,
        input logic [31:0]                seed
    );
        begin
            // pulse async reset
            rst       = 1'b1;
            fmt_sel   = fmt;
            fmt_out   = FMT_FP32;   // read result as FP32 to measure accumulator quality, not output-format range clipping
            operand_a = a;
            operand_b = b;
            acc_seed  = seed;
            @(posedge clk); #1;
            rst = 1'b0;

            // Wait until DUT signals completion rather than guessing cycle count.
            wait (valid_out == 1'b1);
            @(posedge clk); #1;
        end
    endtask

    // -----------------------------------------------------------------
    // Encode helpers (real -> raw bits) for building stimulus.
    // Quick-and-dirty: round-to-nearest via the host's $realtobits path
    // is overkill; we use direct bit constants in tests below to avoid
    // dragging in a quantizer (per Section 6.3 the spec leaves the
    // rounding implementation up to the platform).
    // -----------------------------------------------------------------
    // E4M3 useful constants
    localparam logic [7:0] E4M3_POS_1P0  = 8'b0_0111_000;  // 2^0 * 1.0   = 1.0
    localparam logic [7:0] E4M3_NEG_1P0  = 8'b1_0111_000;  // -1.0
    localparam logic [7:0] E4M3_POS_2P0  = 8'b0_1000_000;  // 2.0
    localparam logic [7:0] E4M3_POS_0P5  = 8'b0_0110_000;  // 0.5
    localparam logic [7:0] E4M3_POS_MAX  = 8'b0_1111_110;  // 448
    localparam logic [7:0] E4M3_ZERO     = 8'h00;
    // E2M1 (FP4) constants (low 4 bits)
    localparam logic [7:0] FP4_POS_1P0   = 8'b0000_0010;   // S=0 E=01 M=0 = 1.0
    localparam logic [7:0] FP4_NEG_1P0   = 8'b0000_1010;   // -1.0
    localparam logic [7:0] FP4_POS_2P0   = 8'b0000_0100;   // E=10 M=0 = 2.0
    localparam logic [7:0] FP4_POS_6P0   = 8'b0000_0111;   // E=11 M=1 = 6.0
    localparam logic [7:0] FP4_ZERO      = 8'h00;

    // -----------------------------------------------------------------
    // Test scenarios
    // -----------------------------------------------------------------
    initial begin
        logic [VECTOR_LEN-1:0][7:0] a;
        logic [VECTOR_LEN-1:0][7:0] b;
        real                        ref_val;
        int                         i;

        pass_count = 0;
        fail_count = 0;
        rst        = 1'b1;

        $display("====================================================");
        $display(" OCP-MX-style reference TB for fma_vector_unit");
        $display(" Oracle: SystemVerilog real (IEEE 754 double)");
        $display(" Block scale X^A = X^B = 1.0 (E8M0 = 127)");
        $display("====================================================");

        // -----------------------------------------------------------------
        // T1: E4M3 all-ones dot product.  Ref = 16. Tests basic correctness.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = E4M3_POS_1P0;
            b[i] = E4M3_POS_1P0;
        end
        run_dot(FMT_E4M3, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_E4M3, a, b, 32'h0000_0000);
        check_result("E4M3: 16*(1.0*1.0)", ref_val, 4);

        // -----------------------------------------------------------------
        // T2: E4M3 alternating signs.  Ref = 0.  Tests cancellation /
        //     guard-round-sticky handling on subtraction.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = (i % 2 == 0) ? E4M3_POS_1P0 : E4M3_NEG_1P0;
            b[i] = E4M3_POS_1P0;
        end
        run_dot(FMT_E4M3, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_E4M3, a, b, 32'h0000_0000);
        check_result("E4M3: alt +-1 (cancellation)", ref_val, 4);

        // -----------------------------------------------------------------
        // T3: E4M3 sparse: 1 nonzero lane, 15 zero lanes.  Ref = 0.5
        //     Tests zero-operand correctness post subnormal fix.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = E4M3_ZERO;
            b[i] = E4M3_ZERO;
        end
        a[3] = E4M3_POS_1P0;
        b[3] = E4M3_POS_0P5;
        run_dot(FMT_E4M3, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_E4M3, a, b, 32'h0000_0000);
        check_result("E4M3: sparse 1*0.5 + 15 zeros", ref_val, 4);

        // -----------------------------------------------------------------
        // T4: E4M3 seed propagation.  All-zero operands, seed = 3.0.
        //     Expect result = 3.0 exactly.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = E4M3_ZERO;
            b[i] = E4M3_ZERO;
        end
        run_dot(FMT_E4M3, a, b, 32'h4040_0000);   // 3.0f
        ref_val = mx_ref_dot(FMT_E4M3, a, b, 32'h4040_0000);
        check_result("E4M3: zero ops, seed=3.0", ref_val, 0);

        // -----------------------------------------------------------------
        // T5: STRESS - bit-25 carry regression.
        //     16 lanes of (2.0 * 2.0) = 4.0  -> sum = 64.0.
        //     With per-cycle carry renormalization this should be exact.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = E4M3_POS_2P0;
            b[i] = E4M3_POS_2P0;
        end
        run_dot(FMT_E4M3, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_E4M3, a, b, 32'h0000_0000);
        check_result("E4M3: bit-25 stress 16*(2*2)=64", ref_val, 4);

        // -----------------------------------------------------------------
        // T6: STRESS - max normal accumulation.
        //     16 lanes of (448*448) = 200704 each -> 3,211,264.
        //     Pushes the accumulator hard; sensitive to bit-25 carry regressions.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = E4M3_POS_MAX;
            b[i] = E4M3_POS_MAX;
        end
        run_dot(FMT_E4M3, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_E4M3, a, b, 32'h0000_0000);
        check_result("E4M3: 16*(448*448) (bit-25 hot)", ref_val, 16);

        // -----------------------------------------------------------------
        // T7: E5M2 wide-range mix.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            // E5M2: 1.0 = S=0, E=01111, M=00 -> 8'b0_01111_00 = 8'h3C
            a[i] = 8'h3C;
            b[i] = 8'h3C;
        end
        run_dot(FMT_E5M2, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_E5M2, a, b, 32'h0000_0000);
        check_result("E5M2: 16*(1.0*1.0)", ref_val, 4);

        // -----------------------------------------------------------------
        // T8: FP4 (E2M1) - shared pipeline with runtime FP4 bias correction.
        //     Ref = 16.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = FP4_POS_1P0;
            b[i] = FP4_POS_1P0;
        end
        run_dot(FMT_FP4, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_FP4, a, b, 32'h0000_0000);
        check_result("FP4: 16*(1.0*1.0)", ref_val, 4);

        // -----------------------------------------------------------------
        // T9: FP4 small-magnitude.  Ref = 16 * 6 * 6 = 576.
        // -----------------------------------------------------------------
        for (i = 0; i < VECTOR_LEN; i++) begin
            a[i] = FP4_POS_6P0;
            b[i] = FP4_POS_6P0;
        end
        run_dot(FMT_FP4, a, b, 32'h0000_0000);
        ref_val = mx_ref_dot(FMT_FP4, a, b, 32'h0000_0000);
        check_result("FP4: 16*(6*6)=576", ref_val, 4);

        // -----------------------------------------------------------------
        // T10: Randomized E4M3 - 8 trials, mostly-zero sparsity ~50%.
        // -----------------------------------------------------------------
        begin : rand_loop
            int trial;
            for (trial = 0; trial < 8; trial++) begin
                for (i = 0; i < VECTOR_LEN; i++) begin
                    if ($urandom_range(0,1)) begin
                        a[i] = E4M3_ZERO;
                        b[i] = E4M3_ZERO;
                    end else begin
                        // Avoid NaN exp = 4'hF
                        do a[i] = $urandom & 8'hFF; while (a[i][6:3] == 4'hF);
                        do b[i] = $urandom & 8'hFF; while (b[i][6:3] == 4'hF);
                    end
                end
                run_dot(FMT_E4M3, a, b, 32'h0000_0000);
                ref_val = mx_ref_dot(FMT_E4M3, a, b, 32'h0000_0000);
                check_result($sformatf("E4M3 random trial %0d", trial), ref_val, 32);
            end
        end

        // -----------------------------------------------------------------
        $display("====================================================");
        $display(" MX-ref TB summary:  PASS=%0d  FAIL=%0d",
                 pass_count, fail_count);
        $display("====================================================");
        $stop;
    end

endmodule
