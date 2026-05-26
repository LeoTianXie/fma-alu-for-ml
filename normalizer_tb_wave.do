onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Inputs
add wave -noupdate -radix binary /normalizer_tb/sign_in
add wave -noupdate -radix unsigned /normalizer_tb/exp_in
add wave -noupdate -radix binary /normalizer_tb/man_in
add wave -noupdate -radix binary /normalizer_tb/guard_bit
add wave -noupdate -radix binary /normalizer_tb/round_bit
add wave -noupdate -radix binary /normalizer_tb/sticky_bit
add wave -noupdate -divider {Stage 1: pre-normalize}
add wave -noupdate -radix binary /normalizer_tb/dut/pre_man
add wave -noupdate -radix binary /normalizer_tb/dut/pre_guard
add wave -noupdate -radix binary /normalizer_tb/dut/pre_round
add wave -noupdate -radix binary /normalizer_tb/dut/pre_sticky
add wave -noupdate -radix decimal /normalizer_tb/dut/pre_exp
add wave -noupdate -divider {Stage 2-3: LZ and shift}
add wave -noupdate -radix unsigned /normalizer_tb/dut/lz
add wave -noupdate -radix binary /normalizer_tb/dut/norm_man
add wave -noupdate -radix binary /normalizer_tb/dut/norm_guard
add wave -noupdate -radix binary /normalizer_tb/dut/norm_round
add wave -noupdate -radix binary /normalizer_tb/dut/norm_sticky
add wave -noupdate -radix decimal /normalizer_tb/dut/norm_exp
add wave -noupdate -divider {Stage 4: rounding}
add wave -noupdate -radix binary /normalizer_tb/dut/round_up
add wave -noupdate -radix binary /normalizer_tb/dut/rounded_man
add wave -noupdate -radix binary /normalizer_tb/dut/final_man
add wave -noupdate -radix decimal /normalizer_tb/dut/final_exp
add wave -noupdate -radix binary /normalizer_tb/dut/is_zero
add wave -noupdate -divider Outputs
add wave -noupdate -radix binary /normalizer_tb/sign_out
add wave -noupdate -radix unsigned /normalizer_tb/exp_out
add wave -noupdate -radix binary /normalizer_tb/man_out
add wave -noupdate -radix binary /normalizer_tb/overflow
add wave -noupdate -radix binary /normalizer_tb/underflow
add wave -noupdate -divider Counters
add wave -noupdate -radix unsigned /normalizer_tb/pass_count
add wave -noupdate -radix unsigned /normalizer_tb/fail_count
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 220
configure wave -valuecolwidth 120
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
WaveRestoreZoom {0 ps} {10527300 ps}
