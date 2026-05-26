onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {E4M3 DUT inputs}
add wave -noupdate -radix binary /exp_aligner_tb/exp4
add wave -noupdate -radix binary /exp_aligner_tb/man4
add wave -noupdate -radix unsigned /exp_aligner_tb/acc_exp4
add wave -noupdate -divider {E4M3 DUT outputs}
add wave -noupdate -radix binary /exp_aligner_tb/man_aligned4
add wave -noupdate -radix unsigned /exp_aligner_tb/common_exp4
add wave -noupdate -radix binary /exp_aligner_tb/guard4
add wave -noupdate -radix binary /exp_aligner_tb/round4
add wave -noupdate -radix binary /exp_aligner_tb/sticky4
add wave -noupdate -divider {E5M2 DUT inputs}
add wave -noupdate -radix binary /exp_aligner_tb/exp5
add wave -noupdate -radix binary /exp_aligner_tb/man5
add wave -noupdate -radix unsigned /exp_aligner_tb/acc_exp5
add wave -noupdate -divider {E5M2 DUT outputs}
add wave -noupdate -radix binary /exp_aligner_tb/man_aligned5
add wave -noupdate -radix unsigned /exp_aligner_tb/common_exp5
add wave -noupdate -radix binary /exp_aligner_tb/guard5
add wave -noupdate -radix binary /exp_aligner_tb/round5
add wave -noupdate -radix binary /exp_aligner_tb/sticky5
add wave -noupdate -divider Counters
add wave -noupdate -radix unsigned /exp_aligner_tb/pass_count
add wave -noupdate -radix unsigned /exp_aligner_tb/fail_count
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
WaveRestoreZoom {0 ps} {27588750 ps}
