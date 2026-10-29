# AGENTS.md

## Project-Specific Instructions

- Project purpose: Caliptra is an open-source hardware root of trust; this Project builds and verifies its RTL.
- Source ownership: `src/` contains Caliptra RTL and verification; `src/integration/config/*.vf` are upstream compile filelists; `src/integration/test_suites/` contains firmware tests. `submodules/adams-bridge/` is an upstream Git submodule at a pinned commit.
- Generated files: `.booley/scripts/generate_core.py` writes `cores/caliptra_rtl.core` (the reusable RTL dependency) and `cores/caliptra_booley.core` (the sim/lint adapter); `generate_tests.py` writes `tests.toml`, keeping unqualified candidates as commented entries with their blockers; `generate_main.py` writes the Verilator `main()`; `.booley/synth/generate_wrapper.py` writes the synthesis wrapper. Rerun the relevant generator after an upstream filelist, port, or test manifest change instead of editing its output. `cores/caliptra_synth.core` is hand-maintained: it depends on the RTL core and holds only synthesis-specific inputs. `cores/caliptra_ecc.core` (block-level ECC Targets `sim_ecc`, `lint_ecc`, `synth_ecc_top`, `synth_ecc_fau`) and `sim/ecc_top_tb_main.cpp` are hand-maintained; `generate_tests.py` appends the `sim_ecc` section of `tests.toml` verbatim.

## Booley-Specific Instructions

- Project-specific Booley data lives in `.booley/`.
- This repo is operating in stealth mode. No changes to `.booley/` may be visible in the main repo. `.booley/` is a separate Git repository with its own history; commit its contents there, not in the main repo.
- Doctor during task work: verify RTL, testbench, firmware, and documentation changes with the relevant Booley Flows (for example `sim` or `lint`) and, at most, plain `booley doctor`. `booley doctor --deep` belongs to Project Setup, `/booley-heal`, and Booley version changes; do not run it for task work or handoffs. Report Doctor findings your change did not cause (pre-existing, host-owned, or Sandbox provisioning) in the handoff instead of fixing them. Never edit `booley.toml`, `.core` files, `doctor-waivers.toml`, or Ticket Board directories to silence such a finding. When the task itself changes project configuration, Targets, dependencies, or the Sandbox, fix the plain Doctor findings that change caused, or add a narrow, reviewed `doctor-waivers.toml` entry for a deliberate constraint, and state in the handoff that deep verification (`/booley-heal`) is due.
- Keep handoffs and plans under `.booley/` (e.g. `.booley/plans/`, `.booley/handoffs/`), never in the RTL repo. They are agent working notes, not project source, and do not belong in source history.
- In Interactive Mode, the editor extension uses the user's shared VS Code window attached to this Project's Sandbox (devcontainer). Use it as the human-facing surface: when useful, open files with `code --goto <path>[:<line>]` and side-by-side diffs with `code --diff <left> <right>` instead of only printing paths.
- Inside the Sandbox, use registered Booley MCP tools for EDA work: choose enabled Flows from `booley.toml` (typically `sim`, `lint`, `synth`, or `fpga`; use `sim --mode elab-only` for an Elaboration Check), and call `booley_status` or `booley targets` for exact wiring. Discover these MCP tools in the tool list—not through `$PATH` or `--help`; if code mode hides them, search `ALL_TOOLS` for `mcp__booley__booley_status`. Run a raw EDA or analysis command inside the Sandbox only when the user explicitly requests a one-off with no matching Flow, and identify it as outside Booley's run-report contract.
- Only if `booley_status` is absent from that MCP tool list are you on the host, where the tools were never registered and nothing is broken. Point the user to "Reopen in Container" (or `booley session up && booley session enter`); do not substitute raw EDA commands.
- At the start of an Interactive Mode tab, call `booley_status` and display its returned status block.
- RISC-V reference docs (keep only for `[sandbox].image = "booley-sandbox-riscv"`) live at `$BOOLEY_RISCV_DOCS` (`/opt/riscv-docs`): offline ISA HTML/PDF, debug specification, and ELF psABI. Start with `$BOOLEY_RISCV_DOCS/INDEX.md`; search HTML directly or extract PDFs with `pdftotext <file.pdf> -`.
- Use Booley Specialists for deeper RTL work: `coverage_analyst` and `mutation_tester` when requested or useful. `reviewer` is disabled.

## Long-Running Flows

- A `sim` or `synth` call holds the turn for up to about 4 minutes, then returns a `run_id` and keeps running in the background. Get its result with `booley_poll` and that `run_id`: `wait_seconds: 0` answers at once, up to 270 blocks until the run finishes. `booley_cancel` stops a job.
- Long jobs here: `synth_ecc_top` (~14 min), a full `sim_ecc` regression (~7 min), the `ECC_normal_test+one` coverage run (~13 min), and `smoke_test_ecdh` on `sim_caliptra` (~20 min with its build). Once one returns its `run_id`, keep working: read code, prepare the next change, run `lint`, and check on the job with `booley_poll` `wait_seconds: 0` between steps.
- Do not wait with `sleep` in Bash, and do not chain long polls while other work is left. Long-poll only when the job's result is the next thing you need.
- Every `sim` and `synth` run, including quick `+one` sims and `synth_ecc_fau`, takes the one heavy slot (`[jobs] max_heavy = 1`): a second call reports `QUEUED` and starts only when the running one ends. Order them on purpose: start the long job whose result you need next, run quick sims between long jobs rather than under them, and never queue `synth_ecc_top` and the coverage run back to back unless you need both.

## Working on Another Branch or Commit (git worktrees)

- To build or simulate another branch/commit without touching the workspace, never use plain `git worktree add`, an arbitrary path, or copy/symlink `.booley/`. A bare checkout lacks Booley state; the live state contains machine-specific runtime data.
- Commit Project changes, then run `booley worktree new <name>` inside the Sandbox from the workspace root (`--help` explains naming). It creates `.booley/worktrees/<name>` with a clean `.booley` snapshot, prints the path, and refuses a name whose destination already exists.
- Pass `work_dir=<worktree path>` to a Flow (`sim`, `lint`, `synth`, ...) to use that checkout; omit it for the normal workspace. Either way, project config comes from the canonical Booley Directory.
- To remove a worktree, follow the steps the command printed; when it printed none, run `git worktree remove <worktree path>`.
- For synthesis/implementation QoR against a past commit, prefer `synth`/`fpga`'s built-in `--baseline <git ref>` over a manual worktree.
