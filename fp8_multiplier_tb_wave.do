onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {E4M3 DUT inputs}
add wave -noupdate -radix binary /fp8_multiplier_tb/a4
add wave -noupdate -radix binary /fp8_multiplier_tb/b4
add wave -noupdate -divider {E4M3 DUT outputs}
add wave -noupdate -radix binary /fp8_multiplier_tb/sign4
add wave -noupdate -radix binary /fp8_multiplier_tb/exp4
add wave -noupdate -radix binary /fp8_multiplier_tb/man4
add wave -noupdate -divider {E5M2 DUT inputs}
add wave -noupdate -radix binary /fp8_multiplier_tb/a5
add wave -noupdate -radix binary /fp8_multiplier_tb/b5
add wave -noupdate -divider {E5M2 DUT outputs}
add wave -noupdate -radix binary /fp8_multiplier_tb/sign5
add wave -noupdate -radix binary /fp8_multiplier_tb/exp5
add wave -noupdate -radix binary /fp8_multiplier_tb/man5
add wave -noupdate -divider Counters
add wave -noupdate -radix unsigned /fp8_multiplier_tb/pass_count
add wave -noupdate -radix unsigned /fp8_multiplier_tb/fail_count
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
WaveRestoreZoom {0 ps} {68836950 ps}
