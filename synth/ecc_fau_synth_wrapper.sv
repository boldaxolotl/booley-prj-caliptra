// SPDX-License-Identifier: Apache-2.0
// Synthesis-only boundary for Goal B ("math unit"): ecc_fau exactly as
// ecc_arith_unit instantiates it (REG_SIZE=384, RADIX=MULT_RADIX=48), with the
// same constant prime/mu selection (p vs q by one select bit), so constant
// propagation into the Montgomery multiplier and adder matches the full design.
// Operands are free ports (in ecc_top they come from the operand RAM's
// registered read ports; results go to its write ports).
module ecc_fau_synth_wrapper
    import ecc_params_pkg::*;
    (
    input  wire                  clk,
    input  wire                  reset_n,
    input  wire                  zeroize,
    input  wire                  add_en_i,
    input  wire                  sub_i,
    input  wire                  mult_en_i,
    input  wire                  mod_q_sel_i,   // ecc_instr_s.opcode.mod_q_sel
    input  wire [REG_SIZE-1:0]   opa_i,
    input  wire [REG_SIZE-1:0]   opb_i,
    output wire [REG_SIZE-1:0]   add_res_o,
    output wire [REG_SIZE-1:0]   mult_res_o
    );

    // Same muxing as ecc_arith_unit.sv (adder_prime / mult_mu).
    wire [REG_SIZE-1:0]   adder_prime = mod_q_sel_i ? GROUP_ORDER    : PRIME;
    wire [MULT_RADIX-1:0] mult_mu     = mod_q_sel_i ? GROUP_ORDER_mu : PRIME_mu;

    ecc_fau #(
        .REG_SIZE(REG_SIZE),
        .RADIX(MULT_RADIX)
        )
        ecc_fau_i (
        .clk(clk),
        .reset_n(reset_n),
        .zeroize(zeroize),
        .add_en_i(add_en_i),
        .sub_i(sub_i),
        .mult_en_i(mult_en_i),
        .prime_i(adder_prime),
        .mult_mu_i(mult_mu),
        .opa_i(opa_i),
        .opb_i(opb_i),
        .add_res_o(add_res_o),
        .mult_res_o(mult_res_o)
    );
endmodule
