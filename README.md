# Caliptra RTL Booley project

A [Booley](https://github.com/boldaxolotl/Booley) project for
[Caliptra RTL](https://github.com/chipsalliance/caliptra-rtl), the open-source
hardware root of trust. It wires Caliptra's Verilator testbench, firmware
tests, lint, ASIC synthesis, and an FPGA build of the ECC engine into Booley
Flows, so an AI agent can simulate, lint, and inspect waveforms of the full SoC
with B-Wave.

It is tested with Caliptra RTL commit
[`e379800c`](https://github.com/chipsalliance/caliptra-rtl/commit/e379800c5467379386f96a9a51a539bd662b608a)
and Booley 0.4.0 at commit
[`2110cb55`](https://github.com/boldaxolotl/Booley/commit/2110cb55618b0bd240d498377ec8dbbcd2f04d5f)
(the 0.5.0 release candidate); see [Known issues](#known-issues-at-the-tested-booley-commit).

## Quick start

[Install Booley](https://github.com/boldaxolotl/Booley#installation) (including
`booley bootstrap`), then clone Caliptra at the tested commit and this project
inside it:

```bash
git clone https://github.com/chipsalliance/caliptra-rtl
cd caliptra-rtl
git checkout e379800c5467379386f96a9a51a539bd662b608a
git submodule update --init --recursive
git clone https://github.com/boldaxolotl/booley-prj-caliptra .booley
```

Apply the small Caliptra patches this project needs (see [Patches](#patches)):

```bash
git switch -c booley
git am .booley/patches/*.patch
```

Give this project's checkout the same branch name, so Booley pairs the two
checkouts:

```bash
git -C .booley switch -c booley
```

The default agent provider is Claude. To use Codex, change `[agent].provider`
in `.booley/booley.toml` before initialization.

Initialize the project on the host:

```bash
booley init
```

Open the `caliptra-rtl` folder in VS Code and choose **Reopen in Container**
(or run **Dev Containers: Reopen in Container** from the Command Palette). The
Sandbox uses the `booley-sandbox-riscv` image, which carries the RISC-V
toolchain for Caliptra firmware, and asks for 28 GB of memory.

In a container terminal, run the deep Doctor gate:

```bash
booley doctor --deep
```

If Doctor reports warnings, use the `/booley-heal` skill to resolve them.

## What you get

| Target | Flow | What it runs |
| --- | --- | --- |
| `sim_caliptra` | `sim` | `caliptra_top_tb` on Verilator; each test builds its firmware first |
| `lint_caliptra` | `lint` | Verilator lint of the full testbench |
| `synth_caliptra` | `synth` | Yosys + OpenROAD ASIC synthesis (Nangate45) |
| `sim_ecc` | `sim` | Block-level `ecc_top_tb` on Verilator: Tests `keygen`, `sign`, `verify`, `ecdh`, `otf_reset`, each printing its operation's cycle count, plus upstream's combined `ECC_normal_test` on one vector (the coverage workload) |
| `lint_ecc` | `lint` | Verilator lint of the ECC RTL |
| `synth_ecc_top` | `synth` | `ecc_top` alone, with the ECC RAM stand-in (about 14 minutes) |
| `synth_ecc_fau` | `synth` | The ECC field arithmetic unit `ecc_fau` through a wrapper (about 2 minutes) |
| `fpga_ecc_top` | `fpga` | `ecc_top` with the same ECC RAM stand-in, placed and routed out of context by Vivado on a Kintex UltraScale+ `xcku5p-ffvb676-2-e` (about 8 minutes) |

`tests.toml` registers 175 upstream firmware tests (for example
`smoke_test_mbox` or `hello_world_iccm`). Tests that do not pass on Verilator
at the tested commit stay in the file as comments, each with its reason. Run
`booley targets` for the exact wiring.

`fpga_ecc_top` needs AMD Vivado 2025.2, which is not in the Sandbox Image. The
KU5P is covered by the free Vivado Standard edition, so no license is needed.
Install Vivado on a Linux x86-64 host, then register it and grant it to this
Project on the host before you open the Sandbox (`booley.toml` already asks for
the host installation with `[eda.vivado] provisioning = "host"`):

```bash
booley eda installation register vivado-2025.2 --kind vivado --source /tools/Xilinx/2025.2
booley eda grant add "$PWD" --kind vivado --installation vivado-2025.2
```

The Grant is tied to the Project's exact path. See Booley's
[Commercial EDA provisioning](https://github.com/boldaxolotl/Booley/blob/main/docs/user/SANDBOX.md#commercial-eda-provisioning).
On a host without Vivado, set `[flows.fpga] enabled = false` and delete the
`[eda.vivado]` table before `booley init`.
`[jobs.seats] vivado = 1` is the Seat Cap: one Vivado build runs at a time, and
a second `fpga` run waits in the queue until the first one ends.

Start a chat in the container with `booley` and ask, for example:

> Run smoke_test_mbox with a waveform trace, then use B-Wave to show me the
> first mailbox write from the firmware.

## Known issues at the tested Booley commit

- **`sim_caliptra` and `lint_caliptra` do not build.** Booley's Sandbox now
  ships Verilator 5.054, which rejects four parameter overrides in the
  `adams-bridge` submodule: inside `` `ifdef VERILATOR ``,
  `compress_top.sv` and `decompress_top.sv` pass five-element
  `INPUT_RATES`/`OUTPUT_RATES` patterns to `abr_piso_multi` with
  `NUM_MODES(4)` (`%Error: Assignment pattern with too many elements`). So
  `booley doctor --deep` fails its `sim_caliptra` and `lint_caliptra` checks
  and self-tests. The block-level ECC Targets are not affected.
- **An `fpga` run started with `booley session enter` stalls after synthesis.**
  The build stops making progress after Vivado prints `Synthesis finished`:
  Vivado's parallel synthesis workers exit, but the Sandbox command supervisor
  never reaps them, and Vivado waits on them. Until
  [boldaxolotl/booley#4048](https://github.com/boldaxolotl/booley/issues/4048)
  is fixed, start the command under a process reaper:

  ```bash
  booley session enter -- /sbin/docker-init -s -- booley flow fpga --target fpga_ecc_top
  ```

## Patches

`patches/` holds five commits for the Caliptra checkout. None changes RTL
behavior.

| Patch | Needed for | What it does |
| --- | --- | --- |
| `0001-fix-firmware-test-build-errors.patch` | `sim` | Fixes compile and link errors in a dozen firmware tests |
| `0002-disable-ocp-lock-for-kv-enforcement.patch` | `sim` | Passes `+CLP_OCP_LOCK_DIS` to `directed_kv_enforcement`, as the test assumes |
| `0003-axi-dma-default-case-arm.patch` | `synth` | Adds an unreachable `default` arm so the Yosys Slang frontend does not infer a combinational loop |
| `0004-ecc-ram-synthesis-hook.patch` | `synth` | Lets synthesis swap the ECC operand RAM for a timing surrogate; inactive unless `USER_ECC_RAM_TDP` is defined |
| `0005-ecc-top-tb-per-operation-tests.patch` | `sim` (`sim_ecc`) | Adds per-operation tests, `+ECC_NUM_VECTORS`, and `[SIM_CYCLES]` cycle reports to the ECC block testbench |

Without them, the affected tests fail to build, synthesis reports a
combinational loop, the ECC RAM is synthesized as flops, and `sim_ecc` has no
per-operation tests. None is fixed on
upstream `main` at `7b901d59` (2026-10-08).
[`patches/README.md`](patches/README.md) explains each patch in detail, and
each commit message repeats its explanation.

## Repository layout

This directory lives at `.booley/` inside the Caliptra checkout. Paths
in `.core` files are relative to the Caliptra root.

| Path | Purpose |
| --- | --- |
| `booley.toml` | Project configuration: agent provider, Sandbox image, Flow settings |
| `AGENTS.md` | Instructions for the AI agent working in this project |
| `tests.toml` | Test registry for `sim_caliptra` (firmware tests) and `sim_ecc` (generated) |
| `cores/caliptra_rtl.core` | FuseSoC core for the Caliptra RTL, built from upstream `.vf` filelists (generated) |
| `cores/caliptra_booley.core` | `sim_caliptra` and `lint_caliptra` Targets (generated) |
| `cores/caliptra_synth.core` | `synth_caliptra` Target |
| `cores/caliptra_ecc.core` | Block-level ECC Targets `sim_ecc`, `lint_ecc`, `synth_ecc_top`, `synth_ecc_fau`, `fpga_ecc_top` |
| `sim/ecc_top_tb_main.cpp` | Verilator `main()` for `sim_ecc`, with trace and coverage support |
| `goalsets/` | Goalsets for Goal Mode, including `ecc-area.md` (shrink the ECC engine) |
| `cores/caliptra_doctor_selftest.core` | Deliberately broken fixture that proves `booley doctor --deep` catches lint failures |
| `generated/test_caliptra_top_tb.cpp` | Upstream Verilator `main()` with per-test plusargs and Booley trace-file support (generated) |
| `scripts/` | Generators for the files above, plus `build_firmware.sh`, which builds each test's firmware before simulation |
| `synth/` | ASIC synthesis wrappers, clock-gate and RAM adapters, SDCs, the `fpga_ecc_top` XDC and SystemVerilog shim, and [`ASIC-REPORT.md`](synth/ASIC-REPORT.md) |
| `selftest/` | Bad-input fixtures for Doctor's fail-path checks |
| `patches/` | Caliptra patches and their [explanations](patches/README.md) |
| `doctor-waivers.toml` | Reviewed Doctor waiver for the known synthesis hold-slack warning |
| `runs/sim/` | Simulation working directory; its contents are ignored |

### Regenerating

The generated files track the tested Caliptra commit. After moving to another
commit, rerun the generators from the Caliptra root and review the diff:

```bash
python3 .booley/scripts/generate_core.py
python3 .booley/scripts/generate_tests.py
python3 .booley/scripts/generate_main.py
python3 .booley/synth/generate_wrapper.py
```

`generate_tests.py` asserts the upstream test counts, so it fails loudly when
the test suite changes. Update its exclusion lists after checking the new tests.

## Notes

- The project runs in stealth mode: `.booley/` is its own Git
  repository, and Caliptra's history gains only the patch commits above.
- The `reviewer` Specialist is disabled in `booley.toml`.
- Synthesis results are prototype numbers (ideal clocks, no SRAM macros, no
  hold repair). The Booley 0.3.0 rerun completed in 42 minutes with the
  reviewed SDC fanout workaround for
  [#1332](https://github.com/boldaxolotl/booley/issues/1332).
  See [`synth/ASIC-REPORT.md`](synth/ASIC-REPORT.md).

## License

Apache License 2.0, the same as Caliptra RTL. See `LICENSE`.
