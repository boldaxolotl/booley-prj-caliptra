# Caliptra ASIC synthesis through Booley

## 2026-09-27 result

The managed `synth_caliptra` flow completed Yosys synthesis and the full
OpenROAD pipeline: placement, `repair_design`, tie-fanout repair, detailed
placement, setup repair, parasitic estimation, and STA. It uses a flattened
Caliptra wrapper, the Slang frontend, Yosys with the fast ABC recipe, and
Nangate45 standard cells. The Target's `arch: xilinx` setting is an Edalize
generic-flow placeholder; this is an ASIC flow, not an FPGA implementation.

Booley grades the run `WARN`. Every setup path meets its constraint, but hold
slack is slightly negative because hold repair is not enabled.

| Measure | 2026-09-23 (placed, unrepaired) | 2026-09-27 (full repair) |
| --- | ---: | ---: |
| Physical report cells | 1,594,959 | 1,594,915 |
| Area | 3,147.8 kGE (Yosys mapped) | 3,255.2 kGE (OpenROAD post-optimization) |
| `clk` setup slack (20 ns) | −5,239.691 ns | +6.959 ns |
| `clk` register-to-register slack | — | +7.174 ns (≈78 MHz) |
| `jtag_tck` setup slack (100 ns) | not constrained | +49.317 ns |
| Hold slack (`clk` / `jtag_tck`) | −135.285 ns | −0.290 / −0.212 ns |
| Elapsed time | 3,377.8 s | 4,300.1 s |
| Peak process-tree RSS | 16,809.25 MiB | 16,836.6 MiB |

`repair_design` inserted about 38.7k buffers and resized about 13k cells
(+3.4% area). No setup-repair move was needed. The worst `clk` path runs from
a register to the `abr_pk_mem_wdata_i` output with 0 ns output delay. The
`jtag_tck` figure is a falling-to-rising half-cycle path, so Booley's headline
"Fmax 20 MHz [jtag_tck]" reflects the 100 ns TCK constraint, not core speed.
Clocks are ideal (no clock-tree synthesis), and no SRAM macro is integrated.
These are prototype PPA numbers, not timing closure or signoff results.

## Constraints (`synth/caliptra.sdc`)

The mapped netlist has two clock roots: 196,975 flops on `clk` and 104 VeeR
debug flops on `jtag_tck`. No divided, muxed, or flop-generated clocks exist.
The SDC declares:

- `clk` at 20 ns;
- `jtag_tck` at 100 ns, asynchronous to `clk` (crossings use
  `dmi_jtag_to_core_sync`);
- `el2_clk`, the gated core clock forwarded to the external ICCM/DCCM, as a
  generated clock rather than a data output;
- 0 ns I/O delays: JTAG pins relative to `jtag_tck`, all other pins relative
  to `clk`, and none on clock ports.

The upstream repository ships no SDC. This file was written by an agent and
kept as a **user-approved exception** to the rule that setup agents never
author timing constraints. Treat its periods and I/O budgets as prototype
choices, not Caliptra requirements.

## RTL patch

`src/axi/rtl/axi_dma_ctrl.sv` gains a `default` arm in the
`rd_req_count_for_payload_next` `case ... inside`. The existing arms already
cover all eight selector values, so behavior is unchanged. Without the default
arm, the Slang frontend does not detect the case as full and emits a hold-value
combinational loop, which Booley correctly reports as critical.
Upstream issue: https://github.com/povik/sv-elab/issues/387. Remove the arm
once that is fixed. Lint stays clean with the patch.

## Synthesis adapters

`cores/caliptra_synth.core` depends on the reusable design list in
`cores/caliptra_rtl.core` and adds:

- `synth/caliptra_synth_wrapper.sv`, which flattens Caliptra's interface ports;
- `synth/nangate45_icg.sv`, which maps the Caliptra and VeeR technology seams
  directly to four `CLKGATE_X1` and 998 `CLKGATETST_X1` cells;
- `synth/ecc_ram_tdp_timing_surrogate.sv`, a synthesis-only,
  depth-independent timing boundary for the active internal ECC 64x384
  dual-port RAM; and
- `synth/caliptra.sdc`, described above.

The mapped netlist contains no latches, no combinational loops, and no
functional RAM. External bulk memories are wrapper ports, and the
source-listed `caliptra_sram` is inactive in this hierarchy.

## Diagnostics

The run reports 3,599 warnings: 3,594 Yosys records (a multiline-parser
expansion of a few dozen raw headers), four OpenROAD advisories, and one ABC
note. The remaining structural items are upstream multiple-driver diagnostics
on VeeR AXI response signals in an early Yosys check. The final netlist check
reports none.

Generated reports stay out of `synth/`, under the ignored
`.booley_project/.runtime/repair-design-experiment/` directory. Run the flow
from the Caliptra checkout:

```bash
booley session enter -- booley flow synth --target synth_caliptra \
  --report-dir .booley_project/.runtime/<name>
```
