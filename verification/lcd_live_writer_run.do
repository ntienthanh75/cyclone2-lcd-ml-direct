vlib work
vlog -sv ../rtl/lcd_live_writer.sv lcd_live_writer_tb.sv
vsim -c lcd_live_writer_tb
run -all
quit -f
