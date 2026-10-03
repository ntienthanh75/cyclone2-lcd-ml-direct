transcript on
cd "D:/fpga/cyclone2-handwriting-ml/verification/uvm"
if {[file exists work_hw]} { vdel -lib work_hw -all }
vlib work_hw
vmap work work_hw
vlog -sv "D:/Program/altera/13.0sp1/modelsim_ase/altera/verilog/src/altera_mf.v"
vlog -sv "D:/fpga/cyclone2-lcd-ml-direct/rtl/touch_frame_adapter.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/xpt2046_reader.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/xpt2046_calibrator.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/touch_capture_top.sv"
vlog -sv "D:/fpga/cyclone2-lcd-ml-direct/rtl/experiments/ml_inference_scanpipe.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/experiments/touch_ml_scanpipe_top.sv" "D:/fpga/cyclone2-lcd-ml-direct/rtl/cyclone2_lcd_ml_hw.sv" "D:/fpga/cyclone2-lcd-ml-direct/verification/cyclone2_lcd_ml_hw_tb.sv"
vsim -t 1ps -L work_hw cyclone2_lcd_ml_hw_tb
run -all
quit -f
