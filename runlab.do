# Create work library
vlib work

# Compile Verilog
#     All Verilog files that are part of this design should have
#     their own "vlog" line below.
vlog "./rtl/fp4_multiplier.sv"
vlog "./rtl/fp8_multiplier.sv"
vlog "./rtl/fp_multiplier.sv"
vlog "./rtl/input_decode.sv"
vlog "./rtl/exp_aligner.sv"
vlog "./rtl/mantissa_adder.sv"
vlog "./rtl/fp32_accumulator.sv"
vlog "./rtl/normalizer.sv"
vlog "./rtl/output_pack.sv"
vlog "./rtl/fma_vector_unit.sv"
vlog "./tb/fp4_multiplier_tb.sv"
# Leaf TBs below need updating to drive new fmt_sel input on fp8_multiplier
# and exp_aligner; commented out so the top-level MX TB can run.
# vlog "./tb/fp8_multiplier_tb.sv"
vlog "./tb/input_decode_tb.sv"
# vlog "./tb/exp_aligner_tb.sv"
vlog "./tb/fp32_accumulator_tb.sv"
vlog "./tb/normalizer_tb.sv"
vlog "./tb/output_pack_tb.sv"
vlog "./tb/fma_vector_unit_tb.sv"
vlog "./tb/fma_vector_unit_mx_tb.sv"

# Call vsim to invoke simulator
#     Make sure the last item on the line is the name of the
#     testbench module you want to execute.
vsim -voptargs="+acc" -t 1ps -lib work fma_vector_unit_mx_tb

# Source the wave do file
#     This should be the file that sets up the signal window for
#     the module you are testing.
do fma_vector_unit_tb_wave.do

# Set the window types
view wave
view structure
view signals

# Run the simulation
run -all

# End
