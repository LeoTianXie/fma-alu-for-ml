# ML Vector FMA ALU

A hierarchical, **variable-precision vector Fused Multiply-Add (FMA) ALU** in SystemVerilog,
built for machine-learning dot products. It multiplies sixteen lanes in a narrow
floating-point format and accumulates them into a wide IEEE-754 FP32 running sum: the
mixed-precision strategy used by modern ML accelerators (narrow multiply, wide accumulate).

One physical datapath supports the three **OCP Microscaling (MX)** element formats, selected
at runtime:

| Format | Layout | Bias | Specials |
|---|---|---|---|
| **E4M3** | 1+4+3 | 7 | NaN only (no Inf) |
| **E5M2** | 1+5+2 | 15 | Inf and NaN |
| **E2M1 (FP4)** | 1+2+1 | 1 | none |

The design targets **IEEE 754-2019** arithmetic conventions (implicit bit, guard/round/sticky,
round-to-nearest-even) and the **OCP MX v1.0** format definitions.

> **📄 Full technical detail:** [`report/ML_Vector_FMA_ALU_Report_Final.pdf`](report/ML_Vector_FMA_ALU_Report_Final.pdf)
> covers the design rationale, microarchitecture, verification methodology, the bugs it
> caught, and the numerical analysis.

## Architecture at a glance

A six-stage pipeline with the narrow→wide precision boundary between the multiply and
accumulate stages. The front-end runs sixteen lanes in parallel (combinational); the lanes are
then streamed one per cycle into a single sequential FP32 accumulator.

```
  Stage 1        Stage 2        Stage 3         Stage 4          Stage 5        Stage 6
 +--------+    +----------+   +----------+   +------------+   +----------+   +----------+
 | input  | -> | multiply |-> | exponent |-> |   FP32     |-> |normalize |-> |  output  |
 | decode |    |          |   |  align   |   | accumulate |   |          |   |   pack   |
 +--------+    +----------+   +----------+   +------------+   +----------+   +----------+
   narrow      narrow -> 2x      transition      wide (FP32)      FP32       configurable
```

| Stage | Module | Role |
|---|---|---|
| 1. Decode | [`rtl/input_decode.sv`](rtl/input_decode.sv) | Unpack sign/exp/mantissa, implicit bit, special flags |
| 2. Multiply | [`rtl/fp_multiplier.sv`](rtl/fp_multiplier.sv) | Parameterized per-format narrow multiply |
| 3. Align | [`rtl/exp_aligner.sv`](rtl/exp_aligner.sv) | Shift product to the FP32 exponent scale, preserve G/R/S |
| 4. Accumulate | [`rtl/fp32_accumulator.sv`](rtl/fp32_accumulator.sv), [`rtl/mantissa_adder.sv`](rtl/mantissa_adder.sv) | Sign-magnitude add into the FP32 running sum |
| 5. Normalize | [`rtl/normalizer.sv`](rtl/normalizer.sv) | Leading-zero shift, exponent adjust, round-to-nearest-even |
| 6. Pack | [`rtl/output_pack.sv`](rtl/output_pack.sv) | Pack to FP32 or a narrow output format, with OCP saturation |

The leaf modules [`rtl/fp4_multiplier.sv`](rtl/fp4_multiplier.sv) and
[`rtl/fp8_multiplier.sv`](rtl/fp8_multiplier.sv) independently verified the narrow arithmetic
before it was folded into the parameterized `fp_multiplier`. The top level
[`rtl/fma_vector_unit.sv`](rtl/fma_vector_unit.sv) ties the lanes, mux, and sequential
accumulator together.

**Key parameters:** `VECTOR_LEN` (lanes, default 16), `EXP_BITS`/`MAN_BITS` (precision split,
default 5/3); the FP32 accumulator is fixed.

## Verification

Two complementary rungs:

1. **Self-checking leaf testbenches** ([`tb/`](tb/)) with exhaustive sweeps where feasible
   (all 256 FP4×FP4 pairs; 65 536 pairs per FP8 format).
2. **An OCP-MX real-valued oracle** ([`tb/fma_vector_unit_mx_tb.sv`](tb/fma_vector_unit_mx_tb.sv))
   that decodes operands to IEEE-754 double, computes the dot product per OCP MX v1.0 §6.1, and
   measures the DUT error in FP32 units in the last place (ulp).

The oracle exposed and fixed three structural arithmetic bugs the self-checking tests could
not: a bit-25 accumulator carry loss, a per-format multiplier bias mismatch, and a subnormal
exponent error.

## Results at a glance

| Metric | Result |
|---|---|
| MX-oracle testbench | **PASS = 15, FAIL = 6** (21 checks) |
| Directed arithmetic tests | **bit-exact to the oracle (0.00 ulp)** across E4M3, E5M2, FP4, and subnormals |
| Remaining failures | 6 randomized mixed-magnitude trials, bounded sub-ulp residual (finite-precision swamping, not a logic bug) |
| Leaf testbenches | all pass their exhaustive/directed sweeps |
| Elaboration | 0 errors, 0 warnings |

See the report for the full before/after table and the residual-error analysis.

## Build & run (ModelSim / Questa)

[`runlab.do`](runlab.do) compiles the design and testbenches in dependency order. From the
ModelSim console at the repo root:

```tcl
do runlab.do
```

To run the headline OCP-MX testbench, point the `vsim` line in `runlab.do` at
`fma_vector_unit_mx_tb`, then:

```tcl
run -all
```

Expected: `PASS = 15  FAIL = 6`, with every directed test at `ulp_err = 0.00`. Randomized
trials use `$urandom`, so the exact failing indices vary by seed; the directed pass set is
deterministic.

> Per-testbench wave configs (`*_wave.do`) are local-only (git-ignored).

## Repository layout

```
rtl/        Synthesizable SystemVerilog (the 10 design modules)
tb/         Self-checking testbenches + the OCP-MX oracle
report/     Full technical report (PDF)
runlab.do   ModelSim compile/run script
DE1_SoC.*   Intel Quartus project files (FPGA target)
```

## Standards & references

- IEEE Std 754-2019, *IEEE Standard for Floating-Point Arithmetic*
- OCP *Microscaling (MX) Formats Specification*, v1.0
- IEEE Std 1800-2017, *IEEE Standard for SystemVerilog*

Full citations are in the report's reference list.
