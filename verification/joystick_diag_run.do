transcript on
if {[file exists work_joystick_diag]} { vdel -lib work_joystick_diag -all }
vlib work_joystick_diag
vmap work work_joystick_diag
vlog -sv "D:/fpga/cyclone2-lcd-ml-direct/rtl/cyclone2_joystick_diag.sv" "D:/fpga/cyclone2-lcd-ml-direct/verification/cyclone2_joystick_diag_tb.sv"
vsim -t 1ps -L work_joystick_diag cyclone2_joystick_diag_tb
run -all
quit -f
