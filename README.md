# Caliptra RTL Booley project

A [Booley](https://github.com/boldaxolotl/Booley) project for
[Caliptra RTL](https://github.com/chipsalliance/caliptra-rtl), the open-source
hardware root of trust. It wires Caliptra's Verilator testbench, firmware
tests, lint, and ASIC synthesis into Booley Flows, so an AI agent can simulate,
lint, and inspect waveforms of the full SoC with B-Wave.

It is tested with Caliptra RTL commit
[`e379800c`](https://github.com/chipsalliance/caliptra-rtl/commit/e379800c5467379386f96a9a51a539bd662b608a)
and Booley 0.3.0.

## Quick start

[Install Booley](https://github.com/boldaxolotl/Booley#installation) (including
`booley bootstrap`), then clone Caliptra at the tested commit and this project
inside it:

```bash
git clone https://github.com/chipsalliance/caliptra-rtl
cd caliptra-rtl
git checkout e379800c5467379386f96a9a51a539bd662b608a
git submodule update --init --recursive
git clone https://github.com/boldaxolotl/booley-prj-caliptra .booley_project
```

Apply the small Caliptra patches this project needs (see [Patches](#patches)):

```bash
git switch -c booley
git am .booley_project/patches/*.patch
```

The default agent provider is Codex. To use Claude, change `[agent].provider`
in `.booley_project/booley.toml` before initialization.

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

`tests.toml` registers 175 upstream firmware tests (for example
`smoke_test_mbox` or `hello_world_iccm`). Tests that do not pass on Verilator
at the tested commit stay in the file as comments, each with its reason. Run
`booley targets` for the exact wiring.

Start a chat in the container with `booley` and ask, for example:

> Run smoke_test_mbox with a waveform trace, then use B-Wave to show me the
> first mailbox write from the firmware.

## Patches

`patches/` holds four commits for the Caliptra checkout. None changes RTL
behavior.

| Patch | Needed for | What it does |
| --- | --- | --- |
| `0001-fix-firmware-test-build-errors.patch` | `sim` | Fixes compile and link errors in a dozen firmware tests |
| `0002-disable-ocp-lock-for-kv-enforcement.patch` | `sim` | Passes `+CLP_OCP_LOCK_DIS` to `directed_kv_enforcement`, as the test assumes |
| `0003-axi-dma-default-case-arm.patch` | `synth` | Adds an unreachable `default` arm so the Yosys Slang frontend does not infer a combinational loop |
| `0004-ecc-ram-synthesis-hook.patch` | `synth` | Lets synthesis swap the ECC operand RAM for a timing surrogate; inactive unless `USER_ECC_RAM_TDP` is defined |

Without them, the affected tests fail to build, synthesis reports a
combinational loop, and the ECC RAM is synthesized as flops. None is fixed on
upstream `main` at `7b901d59` (2026-10-08).
[`patches/README.md`](patches/README.md) explains each patch in detail, and
each commit message repeats its explanation.

## Repository layout

This directory lives at `.booley_project/` inside the Caliptra checkout. Paths
in `.core` files are relative to the Caliptra root.

| Path | Purpose |
| --- | --- |
| `booley.toml` | Project configuration: agent provider, Sandbox image, Flow settings |
| `AGENTS.md` | Instructions for the AI agent working in this project |
| `tests.toml` | Firmware test registry for `sim_caliptra` (generated) |
| `cores/caliptra_rtl.core` | FuseSoC core for the Caliptra RTL, built from upstream `.vf` filelists (generated) |
| `cores/caliptra_booley.core` | `sim_caliptra` and `lint_caliptra` Targets (generated) |
| `cores/caliptra_synth.core` | `synth_caliptra` Target |
| `cores/caliptra_doctor_selftest.core` | Deliberately broken fixture that proves `booley doctor --deep` catches lint failures |
| `generated/test_caliptra_top_tb.cpp` | Upstream Verilator `main()` with per-test plusargs and Booley trace-file support (generated) |
| `scripts/` | Generators for the files above, plus `build_firmware.sh`, which builds each test's firmware before simulation |
| `synth/` | ASIC synthesis wrapper, clock-gate and RAM adapters, SDC, and [`ASIC-REPORT.md`](synth/ASIC-REPORT.md) |
| `selftest/` | Bad-input fixtures for Doctor's fail-path checks |
| `patches/` | Caliptra patches and their [explanations](patches/README.md) |
| `doctor-waivers.toml` | Reviewed Doctor waiver for the known synthesis hold-slack warning |
| `runs/sim/` | Simulation working directory; its contents are ignored |

### Regenerating

The generated files track the tested Caliptra commit. After moving to another
commit, rerun the generators from the Caliptra root and review the diff:

```bash
python3 .booley_project/scripts/generate_core.py
python3 .booley_project/scripts/generate_tests.py
python3 .booley_project/scripts/generate_main.py
python3 .booley_project/synth/generate_wrapper.py
```

`generate_tests.py` asserts the upstream test counts, so it fails loudly when
the test suite changes. Update its exclusion lists after checking the new tests.

## Notes

- The project runs in stealth mode: `.booley_project/` is its own Git
  repository, and Caliptra's history gains only the patch commits above.
- The `reviewer` Specialist is disabled in `booley.toml`; delete the
  `[specialists.reviewer]` table to enable it.
- Synthesis results are prototype numbers (ideal clocks, no SRAM macros, no
  hold repair). The Booley 0.3.0 rerun completed in 42 minutes with the
  reviewed SDC fanout workaround for
  [#1332](https://github.com/boldaxolotl/booley/issues/1332).
  See [`synth/ASIC-REPORT.md`](synth/ASIC-REPORT.md).

## License

Apache License 2.0, the same as Caliptra RTL. See `LICENSE`.
