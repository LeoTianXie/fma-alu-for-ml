`timescale 1ns/1ps

// =========================================================================
// fma_vector_unit testbench
//
// Strategy notes
// --------------
// This bench exercises both cancellation-heavy and same-sign accumulation.
// Same-sign tests intentionally drive the accumulator past the old bit-24
// carry-slot limit; the top level should now renormalize any bit-25 carry
// every cycle and keep accumulating correctly.
//
// Output format is E4M3 (fmt_out=2'b01), packed in result[7:0]; result[31:8]
// is zero per output_pack's contract.
// =========================================================================

module fma_vector_unit_tb;

    localparam int VECTOR_LEN = 16;
    localparam int EXP_BITS   = 5;
    localparam int MAN_BITS   = 3;
    localparam int CLK_PERIOD = 10;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                       clk = 1'b0;
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

    fma_vector_unit #(
        .VECTOR_LEN (VECTOR_LEN),
        .EXP_BITS   (EXP_BITS),
        .MAN_BITS   (MAN_BITS)
    ) dut (
        .fmt_out   (fmt_out),
        .*
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Counters
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // Format constants
    // -------------------------------------------------------------------------
    // E4M3 operand encodings (sign | exp[3:0] | man[2:0])
    localparam logic [7:0] E4M3_ZERO = 8'h00;  // +0    = 0_0000_000
    localparam logic [7:0] E4M3_PONE = 8'h38;  // +1.0  = 0_0111_000
    localparam logic [7:0] E4M3_NONE = 8'hB8;  // -1.0  = 1_0111_000
    localparam logic [7:0] E4M3_PTWO = 8'h40;  // +2.0  = 0_1000_000

    // FP32 seed values
    localparam logic [31:0] FP32_ZERO = 32'h00000000;
    localparam logic [31:0] FP32_PONE = 32'h3F800000;
    localparam logic [31:0] FP32_NONE = 32'hBF800000;
    localparam logic [31:0] FP32_PTWO = 32'h40000000;

    // Expected outputs (E4M3 packed in low byte, upper bits zero)
    localparam logic [31:0] OUT_E4M3_ZERO = 32'h00000000;  // E4M3 +0
    localparam logic [31:0] OUT_E4M3_PONE = 32'h00000038;  // E4M3 +1.0
    localparam logic [31:0] OUT_E4M3_NONE = 32'h000000B8;  // E4M3 -1.0
    localparam logic [31:0] OUT_E4M3_PTWO = 32'h00000040;  // E4M3 +2.0
    localparam logic [31:0] OUT_E4M3_P16  = 32'h00000058;  // E4M3 +16.0
    localparam logic [31:0] OUT_E4M3_P64  = 32'h00000068;  // E4M3 +64.0

    // -------------------------------------------------------------------------
    // Alternating-b helper: returns a vector where b[i]=+1 for even i, -1 for odd
    // Drives the product sequence +1, -1, +1, -1, ... when paired with a=+1.
    // -------------------------------------------------------------------------
    function automatic logic [VECTOR_LEN-1:0][7:0] alt_b();
        logic [VECTOR_LEN-1:0][7:0] v;
        for (int k = 0; k < VECTOR_LEN; k++) begin
            v[k] = (k[0] == 1'b0) ? E4M3_PONE : E4M3_NONE;
        end
        return v;
    endfunction

    // -------------------------------------------------------------------------
    // Test driver: apply reset+inputs, deassert, wait for valid_out, compare.
    // -------------------------------------------------------------------------
    task automatic run_test(
        input logic [VECTOR_LEN-1:0][7:0] a_vec,
        input logic [VECTOR_LEN-1:0][7:0] b_vec,
        input logic [31:0]                seed,
        input logic [1:0]                 fmt,
        input logic [31:0]                expected,
        input string                      label
    );
        int cycles;
        // Apply reset with new inputs.
        rst       = 1'b1;
        operand_a = a_vec;
        operand_b = b_vec;
        acc_seed  = seed;
        fmt_sel   = fmt;
        fmt_out   = fmt;
        @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Wait for valid_out with a generous timeout.
        cycles = 0;
        while (cycles < (VECTOR_LEN + 5)) begin
            @(posedge clk);
            cycles++;
            #1;
            if (valid_out) break;
        end

        if (!valid_out) begin
            $display("FAIL [%-44s] valid_out never asserted (cycles=%0d)",
                     label, cycles);
            fail_count++;
        end else if (result !== expected) begin
            $display("FAIL [%-44s] cycles=%0d got=%08h exp=%08h",
                     label, cycles, result, expected);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // Power-on idle
        rst       = 1'b1;
        fmt_sel   = 2'b01;
        operand_a = '{default: E4M3_PONE};
        operand_b = '{default: E4M3_PONE};
        acc_seed  = FP32_ZERO;
        repeat (3) @(posedge clk);

        // =================================================================
        // Functional tests
        //
        // operand_a = all +1.0, operand_b = alternating ±1.0.
        // Products alternate +1, -1; running sum stays in [seed, seed+1].
        // After 16 cycles (8 pairs), net contribution = 0, so result = seed.
        // =================================================================

        run_test('{default: E4M3_PONE}, alt_b(),
                 FP32_ZERO, 2'b01, OUT_E4M3_ZERO,
                 "alt ±1, seed=0 -> 0");

        run_test('{default: E4M3_PONE}, alt_b(),
                 FP32_PONE, 2'b01, OUT_E4M3_PONE,
                 "alt ±1, seed=+1 -> +1");

        run_test('{default: E4M3_PONE}, alt_b(),
                 FP32_NONE, 2'b01, OUT_E4M3_NONE,
                 "alt ±1, seed=-1 -> -1");

        run_test('{default: E4M3_PONE}, alt_b(),
                 FP32_PTWO, 2'b01, OUT_E4M3_PTWO,
                 "alt ±1, seed=+2 -> +2");

        // =================================================================
        // Sign-coverage test: all operand_a = -1.0, b alternates.
        // Products are -1, +1, -1, +1, ... — same magnitude pattern, but
        // first product is negative. Net still 0, but the running sum dips
        // below zero. Verifies sign handling across both branches.
        // =================================================================

        run_test('{default: E4M3_NONE}, alt_b(),
                 FP32_ZERO, 2'b01, OUT_E4M3_ZERO,
                 "alt -1/+1 (neg first), seed=0 -> 0");

        // =================================================================
        // Same-sign accumulation: these now exercise per-cycle bit-25 carry
        // renormalization instead of being avoided.
        // =================================================================

        run_test('{default: E4M3_PONE}, '{default: E4M3_PONE},
                 FP32_ZERO, 2'b01, OUT_E4M3_P16,
                 "same sign: 16 lanes of +1*+1 -> +16");

        run_test('{default: E4M3_PTWO}, '{default: E4M3_PTWO},
                 FP32_ZERO, 2'b01, OUT_E4M3_P64,
                 "same sign: 16 lanes of +2*+2 -> +64");

        // =================================================================
        // Zero-operand tests (enabled by the |exp_x implicit-bit fix in
        // fp4_multiplier / fp8_multiplier).
        //
        // Before the fix, 8'h00 operands generated a 1.0×2^-7 garbage
        // product, so any "no-op filler" lane corrupted the accumulator.
        // After the fix, 8'h00 × anything produces a clean zero contribution,
        // which lets us exercise sparse ML-style inputs (ReLU outputs,
        // attention masks, sparse activations).
        // =================================================================

        // All-zero operands: accumulator should hold its seed.
        run_test('{default: E4M3_ZERO}, '{default: E4M3_ZERO},
                 FP32_ZERO, 2'b01, OUT_E4M3_ZERO,
                 "all zeros, seed=0 -> 0");

        run_test('{default: E4M3_ZERO}, '{default: E4M3_ZERO},
                 FP32_PONE, 2'b01, OUT_E4M3_PONE,
                 "all zeros, seed=+1 -> +1 (seed propagates)");

        run_test('{default: E4M3_ZERO}, '{default: E4M3_ZERO},
                 FP32_NONE, 2'b01, OUT_E4M3_NONE,
                 "all zeros, seed=-1 -> -1 (sign preserved)");

        // Sparse: one non-zero lane among VECTOR_LEN-1 zeros.
        // Mimics extreme sparsity in ReLU/attention outputs.
        begin
            logic [VECTOR_LEN-1:0][7:0] a_sparse, b_sparse;
            a_sparse = '{default: E4M3_ZERO};
            b_sparse = '{default: E4M3_ZERO};
            a_sparse[0] = E4M3_PONE;
            b_sparse[0] = E4M3_PONE;
            run_test(a_sparse, b_sparse, FP32_ZERO, 2'b01, OUT_E4M3_PONE,
                     "sparse: 1 lane of +1, 15 zeros -> +1");
            run_test(a_sparse, b_sparse, FP32_PONE, 2'b01, OUT_E4M3_PTWO,
                     "sparse + seed=1: 1 lane of +1, 15 zeros -> +2");
        end

        // Two non-zero lanes; rest zero. Tests that bit-24 carry across
        // a zero-filler tail doesn't corrupt the accumulator.
        begin
            logic [VECTOR_LEN-1:0][7:0] a_sparse, b_sparse;
            a_sparse = '{default: E4M3_ZERO};
            b_sparse = '{default: E4M3_ZERO};
            a_sparse[0] = E4M3_PONE; b_sparse[0] = E4M3_PONE;   //  +1
            a_sparse[1] = E4M3_PONE; b_sparse[1] = E4M3_PONE;   //  +1 -> running 2
            run_test(a_sparse, b_sparse, FP32_ZERO, 2'b01, OUT_E4M3_PTWO,
                     "sparse: 2 lanes of +1, 14 zeros -> +2");
        end

        // Sparse cancellation: one +1 and one -1 separated by zero filler.
        begin
            logic [VECTOR_LEN-1:0][7:0] a_sparse, b_sparse;
            a_sparse = '{default: E4M3_ZERO};
            b_sparse = '{default: E4M3_ZERO};
            a_sparse[0] = E4M3_PONE; b_sparse[0] = E4M3_PONE;   //  +1
            a_sparse[8] = E4M3_PONE; b_sparse[8] = E4M3_NONE;   //  -1 (after zero filler)
            run_test(a_sparse, b_sparse, FP32_ZERO, 2'b01, OUT_E4M3_ZERO,
                     "sparse cancel: lane0=+1, lane8=-1, rest 0 -> 0");
        end

        // =================================================================
        // Timing test: valid_out must be 0 for cycles 1..VECTOR_LEN-1 and
        // assert on cycle VECTOR_LEN.
        // =================================================================
        begin
            int wrong;
            rst       = 1'b1;
            operand_a = '{default: E4M3_PONE};
            operand_b = alt_b();
            acc_seed  = FP32_ZERO;
            fmt_sel   = 2'b01;
            @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            wrong = 0;

            // Cycles 1 .. VECTOR_LEN-1: expect valid_out = 0
            for (int k = 1; k < VECTOR_LEN; k++) begin
                @(posedge clk);
                #1;
                if (valid_out) begin
                    $display("FAIL [timing] valid_out asserted early at cycle %0d", k);
                    wrong++;
                end
            end

            // Cycle VECTOR_LEN: expect valid_out = 1
            @(posedge clk);
            #1;
            if (!valid_out) begin
                $display("FAIL [timing] valid_out did not assert at cycle %0d",
                         VECTOR_LEN);
                wrong++;
            end

            if (wrong == 0) begin
                pass_count++;
            end else begin
                fail_count++;
            end
        end

        // =================================================================
        // Reset re-pulse: re-run a known-good test to confirm the unit
        // re-initializes cleanly after the prior runs.
        // =================================================================

        run_test('{default: E4M3_PONE}, alt_b(),
                 FP32_PONE, 2'b01, OUT_E4M3_PONE,
                 "rerun after prior tests");

        // =================================================================
        // Summary
        // =================================================================
        $display("");
        $display("---------------------------------------------------");
        $display("RESULTS: %0d passed, %0d failed (total %0d checks)",
                 pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("*** FAILURES DETECTED ***");
        $display("---------------------------------------------------");

        $stop;
    end

endmodule
