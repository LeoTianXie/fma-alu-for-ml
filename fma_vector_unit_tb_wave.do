onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /fma_vector_unit_tb/VECTOR_LEN
add wave -noupdate /fma_vector_unit_tb/EXP_BITS
add wave -noupdate /fma_vector_unit_tb/MAN_BITS
add wave -noupdate /fma_vector_unit_tb/CLK_PERIOD
add wave -noupdate /fma_vector_unit_tb/E4M3_ZERO
add wave -noupdate /fma_vector_unit_tb/E4M3_PONE
add wave -noupdate /fma_vector_unit_tb/E4M3_NONE
add wave -noupdate /fma_vector_unit_tb/FP32_ZERO
add wave -noupdate /fma_vector_unit_tb/FP32_PONE
add wave -noupdate /fma_vector_unit_tb/FP32_NONE
add wave -noupdate /fma_vector_unit_tb/FP32_PTWO
add wave -noupdate /fma_vector_unit_tb/OUT_E4M3_ZERO
add wave -noupdate /fma_vector_unit_tb/OUT_E4M3_PONE
add wave -noupdate /fma_vector_unit_tb/OUT_E4M3_NONE
add wave -noupdate /fma_vector_unit_tb/OUT_E4M3_PTWO
add wave -noupdate /fma_vector_unit_tb/clk
add wave -noupdate /fma_vector_unit_tb/rst
add wave -noupdate /fma_vector_unit_tb/fmt_sel
add wave -noupdate /fma_vector_unit_tb/operand_a
add wave -noupdate /fma_vector_unit_tb/operand_b
add wave -noupdate /fma_vector_unit_tb/acc_seed
add wave -noupdate /fma_vector_unit_tb/result
add wave -noupdate /fma_vector_unit_tb/overflow
add wave -noupdate /fma_vector_unit_tb/underflow
add wave -noupdate /fma_vector_unit_tb/valid_out
add wave -noupdate /fma_vector_unit_tb/pass_count
add wave -noupdate /fma_vector_unit_tb/fail_count
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1000
configure wave -griddelta 2
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {2526300 ps}
