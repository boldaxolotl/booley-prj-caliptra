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

`tests.toml` registers the upstream firmware tests (for example
`smoke_test_mbox` or `hello_world_iccm`). Run `booley targets` for the exact
wiring.

Start a chat in the container with `booley` and ask, for example:

> Run smoke_test_mbox with a waveform trace, then use B-Wave to show me the
> first mailbox write from the firmware.

## Notes

- The project runs in stealth mode: `.booley_project/` is its own Git
  repository, and Caliptra's checkout stays untouched.
- The `reviewer` Specialist is disabled in `booley.toml`; delete the
  `[specialists.reviewer]` table to enable it.
- `synth/ASIC-REPORT.md` records the reference synthesis result.

## License

Apache License 2.0, the same as Caliptra RTL. See `LICENSE`.
