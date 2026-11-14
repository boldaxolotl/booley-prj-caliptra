// fpga_ecc_top only. Booley's fpga Flow reads .v files as Verilog 2001, but
// the SHA-512 constant tables are SystemVerilog. Including them from this
// .sv file makes Vivado parse them as SystemVerilog without touching
// upstream RTL. The include directory comes from fpga_sha512_constants.
`include "sha512_h_constants.v"
`include "sha512_k_constants.v"
