# ecc_top block-level ASIC synthesis constraints (Nangate45 prototype).
# Derived from caliptra.sdc: same 20 ns clk, 0 ns I/O budgets, permissive
# fanout limit. ecc_top has a single clock port (clk); no jtag_tck/el2_clk.
create_clock -name clk -period 20.0 [get_ports clk]
set_input_delay -clock clk 0.0 [all_inputs -no_clocks]
set_output_delay -clock clk 0.0 [all_outputs]
set_max_fanout 1000000 [current_design]
