onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /output_pack_tb/sign_in
add wave -noupdate /output_pack_tb/exp_in
add wave -noupdate /output_pack_tb/man_in
add wave -noupdate /output_pack_tb/fmt_out
add wave -noupdate /output_pack_tb/result
add wave -noupdate /output_pack_tb/pass_count
add wave -noupdate /output_pack_tb/fail_count
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
WaveRestoreZoom {0 ps} {5296200 ps}
