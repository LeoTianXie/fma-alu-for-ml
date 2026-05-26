# Create work library
vlib work

# Compile Verilog
#     All Verilog files that are part of this design should have
#     their own "vlog" line below.
vlog "./rtl/fp4_multiplier.sv"
vlog "./rtl/fp8_multiplier.sv"
vlog "./rtl/input_decode.sv"
vlog "./rtl/exp_aligner.sv"
vlog "./rtl/mantissa_adder.sv"
vlog "./rtl/fp32_accumulator.sv"
vlog "./rtl/normalizer.sv"
vlog "./tb/normalizer_tb.sv"

# Call vsim to invoke simulator
#     Make sure the last item on the line is the name of the
#     testbench module you want to execute.
vsim -voptargs="+acc" -t 1ps -lib work normalizer_tb

# Source the wave do file
#     This should be the file that sets up the signal window for
#     the module you are testing.
do normalizer_tb_wave.do

# Set the window types
view wave
view structure
view signals

# Run the simulation
run -all

# End
