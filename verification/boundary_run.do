transcript on
if {[file exists work_boundary]} { vdel -lib work_boundary -all }
vlib work_boundary
vmap work work_boundary
vlog -sv "D:/Program/altera/13.0sp1/modelsim_ase/altera/verilog/src/altera_mf.v"
vlog -sv "D:/fpga/cyclone2-lcd-ml-direct/rtl/touch_frame_adapter.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/xpt2046_reader.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/xpt2046_calibrator.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/touch_capture_top.sv"
vlog -sv "D:/fpga/cyclone2-lcd-ml-direct/rtl/experiments/ml_inference_boundary.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/experiments/touch_ml_boundary_top.sv" "D:/fpga/cyclone2-lcd-ml-direct/verification/touch_ml_boundary_top_tb.sv"
vsim -t 1ps -L work_boundary touch_ml_boundary_top_tb
run -all
quit -f
