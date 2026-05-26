onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Product input}
add wave -noupdate -radix binary /fp32_accumulator_tb/sign_p
add wave -noupdate -radix binary /fp32_accumulator_tb/man_aligned
add wave -noupdate -radix unsigned /fp32_accumulator_tb/common_exp
add wave -noupdate -radix binary /fp32_accumulator_tb/guard_bit
add wave -noupdate -radix binary /fp32_accumulator_tb/round_bit
add wave -noupdate -radix binary /fp32_accumulator_tb/sticky_bit
add wave -noupdate -divider {Accumulator input}
add wave -noupdate -radix binary /fp32_accumulator_tb/acc_sign
add wave -noupdate -radix unsigned /fp32_accumulator_tb/acc_exp
add wave -noupdate -radix binary /fp32_accumulator_tb/acc_man
add wave -noupdate -divider {Accumulator output}
add wave -noupdate -radix binary /fp32_accumulator_tb/sign_acc
add wave -noupdate -radix unsigned /fp32_accumulator_tb/exp_acc
add wave -noupdate -radix binary /fp32_accumulator_tb/man_acc
add wave -noupdate -radix binary /fp32_accumulator_tb/guard_acc
add wave -noupdate -radix binary /fp32_accumulator_tb/round_acc
add wave -noupdate -radix binary /fp32_accumulator_tb/sticky_acc
add wave -noupdate -divider {DUT internals}
add wave -noupdate -radix unsigned /fp32_accumulator_tb/dut/acc_shift_amount
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/acc_man_aligned
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/acc_guard
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/acc_round
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/acc_sticky
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/product_mag_ext
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/acc_mag_ext
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/larger_man
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/smaller_man
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/add_a
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/add_b
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/add_cin
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/c0
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/c1
add wave -noupdate -radix binary /fp32_accumulator_tb/dut/c2
add wave -noupdate -divider Counters
add wave -noupdate -radix unsigned /fp32_accumulator_tb/pass_count
add wave -noupdate -radix unsigned /fp32_accumulator_tb/fail_count
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 200
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
WaveRestoreZoom {0 ps} {555450 ps}
