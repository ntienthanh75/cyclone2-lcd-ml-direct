create_clock -name clk50 -period 20.000 [get_ports {clk50}]
# proc_clk toggles every five clk50 edges, therefore its period is 200 ns.
# The generated-clock target is the divider register's output net.
create_generated_clock -name proc_clk -source [get_ports {clk50}] -divide_by 10 [get_nets {proc_clk}]
