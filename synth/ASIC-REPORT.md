# Caliptra ASIC synthesis through Booley

## 2026-10-09 result (Booley 0.3.0)

Measured on the README's tested Caliptra commit `e379800c` with all four
patches in `patches/`, using Booley 0.3.0 and OpenROAD
`26Q3-2927-gc4d317e4fa`. The SDC includes the reviewed fanout workaround
explained below. The earlier 2026-09-27 run used upstream `a5be0398` plus
these patches and a Booley development build from before 0.3.0;
`a5be0398` differs in synthesizable RTL by a one-line constant-width fix in
`src/keyvault/rtl/kv_read_rule_check.sv` (upstream #1402).

The managed `synth_caliptra` flow completed Yosys synthesis and the full
OpenROAD pipeline: placement, `repair_design`, tie-fanout repair, detailed
placement, setup repair, parasitic estimation, and STA. It uses a flattened
Caliptra wrapper, the Slang frontend, Yosys with the fast ABC recipe, and
Nangate45 standard cells. The Target's `arch: xilinx` setting is an Edalize
generic-flow placeholder; this is an ASIC flow, not an FPGA implementation.

Booley grades the run `WARN`: setup constraints are met, but hold slack is
slightly negative because hold repair is not enabled. Six early Yosys
multiple-driver diagnostics also remain (see Diagnostics).

| Measure | 2026-09-27 (pre-0.3.0) | 2026-10-09 (0.3.0) |
| --- | ---: | ---: |
| Physical report cells | 1,594,915 | 1,595,938 |
| Area (OpenROAD post-optimization) | 3,255.2 kGE | 3,259.6 kGE |
| `clk` setup slack (20 ns) | +6.959 ns | +6.700 ns |
| `clk` register-to-register slack | +7.174 ns (≈78 MHz) | +6.767 ns (≈76 MHz) |
| `jtag_tck` setup slack (100 ns) | +49.317 ns | +49.309 ns |
| Hold slack (`clk` / `jtag_tck`) | −0.290 / −0.212 ns | −0.242 / −0.242 ns |
| Elapsed time | 4,300.1 s | 2,546.2 s (42.4 min) |
| Peak process-tree RSS | 16,836.6 MiB | 16,344.5 MiB |
| Actionable EDA warnings | 3,599 | 6 |

The 0.3.0 run's `repair_design` took 515.7 s, inserted 42,059 buffers,
and resized 12,923 cells (+3.6% area). No setup-repair move was needed.
The worst `clk` path ends at the clock-gating enable check in
`dut.rvtop.veer.ifu.mem_ctl.misc1_ff.genblock.clkhdr.clkhdr.u_icg`.
Booley labels it I/O-bound, but the saved STA report identifies a clock-gating
check, not a data output. The `jtag_tck` figure is a falling-to-rising
half-cycle path, so the headline "Fmax 20 MHz [jtag_tck]" is not core speed.
Clocks are ideal (no clock-tree synthesis), and no SRAM macro is integrated.
These are prototype PPA numbers, not timing closure or signoff results.

Booley 0.3.0 also changes physical-flow defaults (placement density 0.80,
core margins, design-wide buffer removal, and no `FA_X1`/`HA_X1` cells in ABC
mapping) and filters known false-positive warnings. The two runs use different
upstream revisions and tool builds; this is a historical comparison, not a
controlled runtime benchmark.

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
  that keeps fanout repair from dominating this prototype flow.

The upstream repository ships no SDC. This file was written for this port by
an AI agent and reviewed by a human. Treat its periods and I/O budgets as
prototype choices, not Caliptra requirements.

### OpenROAD fanout workaround

The OpenROAD build bundled with Booley 0.3.0 applies a default max fanout of
50 when neither the library nor the SDC supplies one. Caliptra has reset and
power-good nets with up to about 114k loads. The unmodified SDC caused one
run to hit the two-hour timeout in `repair_design`; a second run was stopped
while still in repair. The reviewed explicit limit above avoids that fanout
repair while retaining slew and capacitance repair, restoring the earlier
flow's behavior. This is a runtime workaround, not physical fanout closure.
See [Booley #1332](https://github.com/boldaxolotl/booley/issues/1332).
With it, the full rerun completed comfortably within the project's existing
two-hour timeout.

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

The mapped netlist contains no latches, no combinational loops, and no
functional RAM. External bulk memories are wrapper ports, and the
source-listed `caliptra_sram` is inactive in this hierarchy.

## Diagnostics

The 0.3.0 run reports six actionable Yosys multiple-driver diagnostics on
VeeR AXI response signals (`ifu_axi_bid`, `ifu_axi_bresp`, and
`ifu_axi_bvalid`) from an early check. The final structural report contains
zero multiple-driven signals, zero latches, and zero combinational loops.

The older run reported 3,599 warnings, mostly per-bit "wire is used but has
no driver" messages caused by Liberty cells read without port directions.
Booley 0.3.0 filters those known false positives and tool advisories.

## Reproducing

Apply the patches in `patches/` (see the README), then run the flow from the
Caliptra checkout. Pick any report directory under the ignored
`.booley_project/.runtime/`:

```bash
booley session enter -- booley flow synth --target synth_caliptra \
  --report-dir .booley_project/.runtime/<name>
```
