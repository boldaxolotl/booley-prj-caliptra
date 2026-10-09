# Caliptra top ASIC synthesis constraints (Nangate45 prototype).
#
# The mapped netlist has exactly two clock roots: every flop clock pin traces
# to port clk or port jtag_tck through buffers and ICGs. No divided, muxed, or
# flop-generated clocks exist.

# Core clock: 50 MHz.
create_clock -name clk -period 20.0 [get_ports clk]

# VeeR debug-module JTAG clock (104 flops). 10 MHz is a typical TCK rate.
# JTAG<->core traffic crosses via dmi_jtag_to_core_sync, so the domains are
# asynchronous.
create_clock -name jtag_tck -period 100.0 [get_ports jtag_tck]
set_clock_groups -asynchronous -group {clk} -group {jtag_tck}

# el2_clk forwards VeeR's ICG-gated active clock to the external ICCM/DCCM.
# Declare it as a clock so STA does not time the clock waveform as data.
create_generated_clock -name el2_clk -source [get_ports clk] -divide_by 1 \
  [get_ports el2_clk]

# I/O budgets: JTAG pins are relative to TCK, everything else to clk. Clock
# ports (-no_clocks) and the forwarded clock get no I/O delay.
set jtag_input_names {jtag_tms jtag_tdi jtag_trst_n}
set jtag_output_names {jtag_tdo jtag_tdoEn}
set core_inputs {}
foreach port [all_inputs -no_clocks] {
  if {[lsearch -exact $jtag_input_names [get_full_name $port]] < 0} {
    lappend core_inputs $port
  }
}
set core_outputs {}
foreach port [all_outputs] {
  set name [get_full_name $port]
  if {$name ne "el2_clk" && [lsearch -exact $jtag_output_names $name] < 0} {
    lappend core_outputs $port
  }
}

set_input_delay -clock clk 0.0 $core_inputs
set_output_delay -clock clk 0.0 $core_outputs
set_input_delay -clock jtag_tck 0.0 [get_ports $jtag_input_names]
set_output_delay -clock jtag_tck 0.0 [get_ports $jtag_output_names]

# Fanout: no limit. Caliptra has very large reset and power-good nets (about
# 114k loads on one reset). OpenROAD from 26Q3 applies a default max fanout of
# 50 when neither the library nor the SDC sets one, and its repair_design then
# spends hours buffering those nets. A huge limit leaves fanout alone, so
# repair_design fixes only slew and capacitance violations, as before.
set_max_fanout 1000000 [current_design]
