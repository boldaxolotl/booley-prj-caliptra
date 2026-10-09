// SPDX-License-Identifier: Apache-2.0
// Synthesis-only clock-gate adapters for Booley's Nangate45 reference flow.

(* blackbox *) module CLKGATE_X1 (
    input  logic CK,
    input  logic E,
    output logic GCK
);
endmodule

(* blackbox *) module CLKGATETST_X1 (
    input  logic CK,
    input  logic E,
    input  logic SE,
    output logic GCK
);
endmodule

module caliptra_nangate45_icg (
    input  logic clk,
    input  logic en,
    output logic clk_cg
);
    CLKGATE_X1 u_icg (
        .CK  (clk),
        .E   (en),
        .GCK (clk_cg)
    );
endmodule

module veer_nangate45_icg (
    input  logic SE,
    input  logic EN,
    input  logic CK,
    output logic Q
);
    CLKGATETST_X1 u_icg (
        .CK  (CK),
        .E   (EN),
        .SE  (SE),
        .GCK (Q)
    );
endmodule
