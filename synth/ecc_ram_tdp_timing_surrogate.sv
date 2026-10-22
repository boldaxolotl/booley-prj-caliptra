// SPDX-License-Identifier: Apache-2.0
// Synthesis-only timing boundary for the ECC point-multiplication RAM.
// This preserves interface timing endpoints, not memory contents or capacity.

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

    // Keep independent, depth-invariant endpoints for both write ports.
    (* keep = "true" *) logic [ADDR_WIDTH-1:0] write_addra_q;
    (* keep = "true" *) logic [DATA_WIDTH-1:0] write_dataa_q;
    (* keep = "true" *) logic [ADDR_WIDTH-1:0] write_addrb_q;
    (* keep = "true" *) logic [DATA_WIDTH-1:0] write_datab_q;

    // Registered read startpoints preserve enable and one-cycle visibility.
    (* keep = "true" *) logic [ADDR_WIDTH-1:0] read_addra_q;
    (* keep = "true" *) logic [ADDR_WIDTH-1:0] read_addrb_q;

    function automatic logic [DATA_WIDTH-1:0] read_signature(
        input logic [ADDR_WIDTH-1:0] address
    );
        read_signature = '0;
        read_signature[ADDR_WIDTH-1:0] = address;
    endfunction

    always_comb begin
        douta = read_signature(read_addra_q);
        doutb = read_signature(read_addrb_q);
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            read_addra_q <= '0;
            read_addrb_q <= '0;
        end else if (zeroize) begin
            read_addra_q <= '0;
            read_addrb_q <= '0;
        end else begin
            if (ena)
                read_addra_q <= addra;
            if (enb)
                read_addrb_q <= addrb;
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_addra_q <= '0;
            write_dataa_q <= '0;
            write_addrb_q <= '0;
            write_datab_q <= '0;
        end else if (zeroize) begin
            write_addra_q <= '0;
            write_dataa_q <= '0;
            write_addrb_q <= '0;
            write_datab_q <= '0;
        end else begin
            if (ena && wea) begin
                write_addra_q <= addra;
                write_dataa_q <= dina;
            end
            if (enb && web) begin
                write_addrb_q <= addrb;
                write_datab_q <= dinb;
            end
        end
    end

endmodule
