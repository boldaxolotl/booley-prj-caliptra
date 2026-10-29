# Goalset: ecc-area

This file belongs to the Project: edit and extend it freely.
`booley init` creates the starter Goalsets but never this one.

Shrink the secp384 ECC engine (`ecc_top`, sources in `src/ecc/rtl/`) by
15 % without slowing it down, breaking it, or weakening its security
countermeasures. When a session enters Goal Mode with this Goalset, the agent
translates it into the entry tool's Goal arguments below, unchanged. Every Goal
is mandatory.

## Goals

- `SYNTH:synth_ecc_top`: `ecc_top` area at most 426.2 kGE (−15 % of the
  501.4 kGE baseline) and Fmax at least 169.2 MHz (−5 % of 178.1 MHz).
- `SYNTH:synth_ecc_fau`: the field arithmetic unit `ecc_fau` (Montgomery
  multiplier and modular adder) at most 178.8 kGE (−15 % of 210.3 kGE) and
  Fmax at least 207.0 MHz (−5 % of 217.9 MHz).
- `CYCLE_COUNT:sim_ecc` for each of `keygen`, `sign`, `verify` and `ecdh`:
  at most 10 % more cycles than the baseline of 719,675 / 736,978 / 960,405 /
  717,421 cycles, that is at most 791,642 / 810,675 / 1,056,445 / 789,163.
- `SIM:sim_ecc`: every Test passes: `keygen`, `sign`, `verify`, `ecdh` and
  `otf_reset` on all 10 shipped vectors, and `ECC_normal_test` (all four
  operations) on the first vector.
- `COVERAGE:sim_ecc`: on `ECC_normal_test+one` (all four operations on the
  first vector), line, branch and toggle coverage of the Target's RTL stay
  within 2 points of the baseline (98.58 / 77.19 / 88.98 %).
- `SIM:sim_caliptra` for each of `smoke_test_ecdh`,
  `smoke_test_zeroize_crypto` and `smoke_test_kv_len_mismatch_ecc`: the
  whole Caliptra chip still builds with the changed ECC engine and these
  chip-level firmware tests pass. They are a quick check of the chip-level
  ECC tests, not all of them.
- `LINT:lint_ecc`: the ECC RTL lints clean.

The RTL you may change is the hand-written ECC RTL: everything in
`src/ecc/rtl/` except the generated register block (`ecc_reg.sv`,
`ecc_reg_pkg.sv`, `ecc_reg_uvm.sv`) and the operand RAM
(`ecc_ram_tdp_file.sv`). These 20 files:

<!-- editable-rtl:begin -->
- `src/ecc/rtl/ecc_add_sub_mod_alter.sv`
- `src/ecc/rtl/ecc_adder.sv`
- `src/ecc/rtl/ecc_arith_unit.sv`
- `src/ecc/rtl/ecc_defines_pkg.sv`
- `src/ecc/rtl/ecc_dsa_ctrl.sv`
- `src/ecc/rtl/ecc_dsa_sequencer.sv`
- `src/ecc/rtl/ecc_dsa_uop_pkg.sv`
- `src/ecc/rtl/ecc_fau.sv`
- `src/ecc/rtl/ecc_hmac_drbg_interface.sv`
- `src/ecc/rtl/ecc_montgomerymultiplier.sv`
- `src/ecc/rtl/ecc_mult_dsp.sv`
- `src/ecc/rtl/ecc_params_pkg.sv`
- `src/ecc/rtl/ecc_pe.sv`
- `src/ecc/rtl/ecc_pe_final.sv`
- `src/ecc/rtl/ecc_pe_first.sv`
- `src/ecc/rtl/ecc_pm_ctrl.sv`
- `src/ecc/rtl/ecc_pm_sequencer.sv`
- `src/ecc/rtl/ecc_pm_uop_pkg.sv`
- `src/ecc/rtl/ecc_scalar_blinding.sv`
- `src/ecc/rtl/ecc_top.sv`
<!-- editable-rtl:end -->

You may also improve the testbench `src/ecc/tb/ecc_top_tb.sv`, but not weaken
any existing check.

## Off-limits

These are part of the task's definition, not levers. The final design is
also checked by an independent design review outside Goal Mode; changing any
of them fails that review even when every Goal here is met:

- SHA-512 masking in the HMAC-DRBG path and its randomness.
- Scalar blinding and `RND_SIZE`.
- Freshness of `lambda` and `masking_rnd`: every operation draws new values.
- Zeroize and the asynchronous resets: everything that is cleared today
  stays cleared.
- Range checks on inputs (privkey, R, S, public key). `pk_chk` may be
  re-encoded but not dropped.
- The KeyVault and PCR-signing paths.
- The register map (`ecc_reg.rdl` and its generated `ecc_reg.sv`,
  `ecc_reg_pkg.sv`).
- The operand RAM (`ecc_ram_tdp_file.sv`), its synthesis stand-in
  (`.booley/synth/ecc_ram_tdp_timing_surrogate.sv`) and the
  `USER_ECC_RAM_TDP` hook in `ecc_arith_unit.sv`.
- The synthesis recipe: the `synth_ecc_top` and `synth_ecc_fau` Targets in
  `.booley/cores/caliptra_ecc.core` (flow options, ABC recipe, PPA profile,
  flattening, parameters), the wrapper `.booley/synth/ecc_fau_synth_wrapper.sv`,
  and the 20 ns clock in `.booley/synth/ecc_top.sdc`. Keep `ecc_fau`'s ports and
  parameters so the wrapper still instantiates it as `ecc_arith_unit` does.
- The `sim_ecc` and `lint_ecc` Targets, `tests.toml`, and the test vectors.

## Notes

- One full `sim_ecc` run takes about 7 minutes; `--test <name>+one` runs one
  vector in under a minute. A hung design waits for `[flows.sim].timeout_ms`
  (2 hours, sized for the chip); pass `timeout_ms: 600000` to `sim` calls.
- `synth_ecc_top` takes about 14 minutes and `synth_ecc_fau` about 2.
- A coverage run of `ECC_normal_test+one` takes about 13 minutes;
  coverage is about 16 times slower than plain simulation.
- The chip Target `sim_caliptra` builds the full Caliptra chip testbench
  (about 6 minutes, reused while the RTL is unchanged) and each test's
  firmware. `smoke_test_ecdh` then runs about 15 minutes, the other two
  about a minute each. The chip testbench reaches into ECC internals by
  hierarchical path (`src/integration/tb/caliptra_top_tb_services.sv`), so
  renaming or removing an internal signal can break the chip build even
  when `sim_ecc` passes. Pass `timeout_ms: 3600000` to chip `sim` calls.

## Goal arguments

```json
[
  {
    "family": "SYNTH",
    "target": "synth_ecc_top",
    "thresholds": {"area_kge_max": 426.2, "fmax_mhz_min": 169.2},
    "origin": "ecc-area"
  },
  {
    "family": "SYNTH",
    "target": "synth_ecc_fau",
    "thresholds": {"area_kge_max": 178.8, "fmax_mhz_min": 207.0},
    "origin": "ecc-area"
  },
  {
    "family": "CYCLE_COUNT",
    "target": "sim_ecc",
    "test": "keygen",
    "thresholds": {"cycle_count_max": 791642},
    "origin": "ecc-area"
  },
  {
    "family": "CYCLE_COUNT",
    "target": "sim_ecc",
    "test": "sign",
    "thresholds": {"cycle_count_max": 810675},
    "origin": "ecc-area"
  },
  {
    "family": "CYCLE_COUNT",
    "target": "sim_ecc",
    "test": "verify",
    "thresholds": {"cycle_count_max": 1056445},
    "origin": "ecc-area"
  },
  {
    "family": "CYCLE_COUNT",
    "target": "sim_ecc",
    "test": "ecdh",
    "thresholds": {"cycle_count_max": 789163},
    "origin": "ecc-area"
  },
  {
    "family": "SIM",
    "target": "sim_ecc",
    "origin": "ecc-area"
  },
  {
    "family": "COVERAGE",
    "target": "sim_ecc",
    "tests": ["ECC_normal_test+one"],
    "metrics": {"line": 96.58, "branch": 75.18, "toggle": 86.97},
    "origin": "ecc-area"
  },
  {
    "family": "SIM",
    "target": "sim_caliptra",
    "test": "smoke_test_ecdh",
    "origin": "ecc-area"
  },
  {
    "family": "SIM",
    "target": "sim_caliptra",
    "test": "smoke_test_zeroize_crypto",
    "origin": "ecc-area"
  },
  {
    "family": "SIM",
    "target": "sim_caliptra",
    "test": "smoke_test_kv_len_mismatch_ecc",
    "origin": "ecc-area"
  },
  {
    "family": "LINT",
    "target": "lint_ecc",
    "origin": "ecc-area"
  }
]
```
