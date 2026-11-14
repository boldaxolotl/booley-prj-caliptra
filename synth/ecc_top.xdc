# ecc_top FPGA implementation constraints (fpga_ecc_top, out of context).
# Derived from synth/ecc_top.sdc with the maintainer's approval: the same
# 20 ns clk and 0 ns I/O budgets. The ASIC-only set_max_fanout workaround has
# no FPGA meaning and is left out.
#
# The input budget is a setup (-max) budget only. With a 0 ns minimum input
# delay, every input port that feeds a flop directly fails hold by about
# 0.08 ns, because the capture clock reaches the flop through the clock tree
# and the out-of-context input has no routing delay to match. That check
# models no real path: inside a chip these inputs come from other flops on
# clk. Register-to-register hold is still checked.
create_clock -name clk -period 20.0 [get_ports clk]
set_input_delay -clock clk -max 0.0 [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_output_delay -clock clk 0.0 [all_outputs]
