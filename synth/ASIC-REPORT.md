# Caliptra ASIC synthesis through Booley

## Result

Measured on 2026-10-09 with Booley 0.3.0 and OpenROAD
`26Q3-2927-gc4d317e4fa`, on the README's tested Caliptra commit `e379800c`
with all four patches in `patches/`.

The managed `synth_caliptra` flow runs Yosys synthesis and the full OpenROAD
pipeline: placement, `repair_design`, tie-fanout repair, detailed placement,
setup repair, parasitic estimation, and STA. It uses a flattened Caliptra
wrapper, the Slang frontend, Yosys with the fast ABC recipe, and Nangate45
standard cells. Booley 0.3.0 runs the physical flow at placement density 0.80
with core margins and design-wide buffer removal, and keeps `FA_X1`/`HA_X1`
cells out of ABC mapping. The Target's `arch: xilinx` setting is an Edalize
generic-flow placeholder; this is an ASIC flow, not an FPGA implementation.

Booley grades the run `WARN`. Setup is met on both clocks, but hold slack is
slightly negative because hold repair is not enabled, and six Yosys
multiple-driver diagnostics remain (see [Diagnostics](#diagnostics)).

| Measure | Value |
| --- | ---: |
| Physical report cells | 1,595,938 |
| Area (OpenROAD post-optimization) | 3,259.6 kGE |
| `clk` setup slack (20 ns) | +6.700 ns |
| `clk` register-to-register slack | +6.767 ns (≈76 MHz) |
| `jtag_tck` setup slack (100 ns) | +49.309 ns |
| Hold slack (`clk` / `jtag_tck`) | −0.242 / −0.242 ns |
| Elapsed time | 2,546.2 s (42.4 min) |
| Peak process-tree RSS | 16,344.5 MiB |
| Actionable EDA warnings | 6 |

How to read these numbers:

- `repair_design` took 515.7 s, inserted 42,059 buffers, and resized 12,923
  cells (+3.6% area). Setup repair made no moves.
- The worst `clk` path ends at the clock-gating enable check in
  `dut.rvtop.veer.ifu.mem_ctl.misc1_ff.genblock.clkhdr.clkhdr.u_icg`. Booley
  labels it I/O-bound, but the saved STA report identifies a clock-gating
  check, not a data output.
- The `jtag_tck` figure is a falling-to-rising half-cycle path, so the
  headline "Fmax 20 MHz [jtag_tck]" is not core speed.
- Clocks are ideal (no clock-tree synthesis), and no SRAM macro is integrated.
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
  to `clk`, and none on clock ports;
- `set_max_fanout 1000000 [current_design]`, a deliberately permissive limit
  (see below).

The upstream repository ships no SDC. An AI agent wrote this file for this
port and a human reviewed it. Treat its periods and I/O budgets as prototype
choices, not Caliptra requirements.

### OpenROAD fanout workaround

The OpenROAD build bundled with Booley 0.3.0 applies a default max fanout of
50 when neither the library nor the SDC supplies one. Caliptra has reset and
power-good nets with up to about 114k loads, and at that default
`repair_design` does not finish within the project's two-hour timeout. The
explicit limit skips fanout repair and keeps slew and capacitance repair, so
the run finishes well inside the timeout. This is a runtime workaround, not
physical fanout closure. See
[Booley #1332](https://github.com/boldaxolotl/booley/issues/1332).

## RTL patches

Two patches in `patches/` matter for synthesis.

`patches/0003-axi-dma-default-case-arm.patch` gives
`src/axi/rtl/axi_dma_ctrl.sv` a `default` arm in the
`rd_req_count_for_payload_next` `case ... inside`. The existing arms already
cover all eight selector values, so behavior is unchanged. Without the default
arm, the Slang frontend does not detect the case as full and emits a hold-value
combinational loop, which Booley correctly reports as critical.
Upstream issue: https://github.com/povik/sv-elab/issues/387. Drop the patch
once that is fixed. Lint stays clean with the patch.

`patches/0004-ecc-ram-synthesis-hook.patch` lets a `USER_ECC_RAM_TDP` macro
replace the ECC unit's `ecc_ram_tdp_file` instance. `synth_caliptra` defines it
to `caliptra_ecc_ram_tdp_timing_surrogate` (below). The macro is undefined
elsewhere, so simulation is unchanged. Without this patch the 64x384 RAM is
synthesized as about 25k flops and the numbers above do not reproduce.

## Synthesis adapters

`cores/caliptra_synth.core` depends on the reusable design list in
`cores/caliptra_rtl.core` and adds:

- `synth/caliptra_synth_wrapper.sv`, which flattens Caliptra's interface ports;
- `synth/nangate45_icg.sv`, which maps the Caliptra and VeeR technology seams
  directly to four `CLKGATE_X1` and 998 `CLKGATETST_X1` cells;
- `synth/ecc_ram_tdp_timing_surrogate.sv`, a synthesis-only,
  depth-independent timing boundary for the active internal ECC 64x384
  dual-port RAM, selected through the `USER_ECC_RAM_TDP` hook; and
- `synth/caliptra.sdc`, described above.

The mapped netlist contains no functional RAM. External bulk memories are
wrapper ports, and the source-listed `caliptra_sram` is inactive in this
hierarchy.

## Diagnostics

An early Yosys check reports six actionable multiple-driver diagnostics on
VeeR AXI response signals (`ifu_axi_bid`, `ifu_axi_bresp`, and
`ifu_axi_bvalid`). The final structural report contains zero multiple-driven
signals, zero latches, and zero combinational loops.

Booley filters tool advisories and known false positives, such as the per-bit
"wire is used but has no driver" messages caused by Liberty cells read without
port directions.

## Reproducing

Apply the patches in `patches/` (see the README), then run the flow from the
Caliptra checkout. Pick any report directory under the ignored
`.booley_project/.runtime/`:

```bash
booley session enter -- booley flow synth --target synth_caliptra \
  --report-dir .booley_project/.runtime/<name>
```
