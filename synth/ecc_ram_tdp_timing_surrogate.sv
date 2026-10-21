// SPDX-License-Identifier: Apache-2.0
// Synthesis-only stand-in for the ECC point-multiplication RAM (64x384 TDP).
//
// Why this exists: the real ecc_ram_tdp_file would be ~25k standard-cell
// flops; a production chip uses an SRAM macro instead, and Booley's synth flow
// has no hard-macro (LEF/LIB) support. This stand-in keeps the RAM's interface
// timing endpoints at a small, fixed area, with no storage array.
//
// Why the read data must depend on the write data: everything downstream of
// douta/doutb (Montgomery multiplier, modular adder, result CSRs, DSA control)
// is only real logic if its inputs are not constants. A stand-in whose read
// data is a constant (or only the address) lets a flattening synthesizer
// constant-fold and delete that logic, which under-reports area and moves the
// critical path. Here every dina/dinb bit reaches douta/doutb through a
// register, and the read address is folded in, so no downstream bit is
// constant-foldable.
//
// Behavior (per port, 1-cycle registered read like ecc_ram_tdp_file):
//   douta <= (wea ? dina : dinb) ^ zero_extend(addra)   when ena
//   doutb <= (web ? dinb : dina) ^ zero_extend(addrb)   when enb
// Async reset and synchronous zeroize clear both read registers. The stand-in
// is 2 x DATA_WIDTH flops (the real RAM's read-output registers) plus a 2:1 mux
// and an address XOR per port, independent of depth. It does NOT hold data:
// simulation through it is meaningless; use it for synthesis only.

module caliptra_ecc_ram_tdp_timing_surrogate #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     reset_n,
    input  wire                     zeroize,

    input  wire                     ena,
    input  wire                     wea,
    input  wire [ADDR_WIDTH-1:0]    addra,
    input  wire [DATA_WIDTH-1:0]    dina,
    output logic [DATA_WIDTH-1:0]   douta,

    input  wire                     enb,
    input  wire                     web,
    input  wire [ADDR_WIDTH-1:0]    addrb,
    input  wire [DATA_WIDTH-1:0]    dinb,
    output logic [DATA_WIDTH-1:0]   doutb
);

    // Write data seen by each read port: its own port's data when that port
    // writes, otherwise the other port's data. Both ports' data and both
    // write enables therefore stay observable.
    logic [DATA_WIDTH-1:0] next_douta;
    logic [DATA_WIDTH-1:0] next_doutb;

    always_comb begin
        next_douta = (wea ? dina : dinb) ^ DATA_WIDTH'(addra);
        next_doutb = (web ? dinb : dina) ^ DATA_WIDTH'(addrb);
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            douta <= '0;
            doutb <= '0;
        end else if (zeroize) begin
            douta <= '0;
            doutb <= '0;
        end else begin
            if (ena)
                douta <= next_douta;
            if (enb)
                doutb <= next_doutb;
        end
    end

endmodule
