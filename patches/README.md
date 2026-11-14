# Caliptra patches

This project needs five small commits on top of Caliptra RTL commit
[`e379800c`](https://github.com/chipsalliance/caliptra-rtl/commit/e379800c5467379386f96a9a51a539bd662b608a).
Apply them from the Caliptra checkout root:

```bash
git switch -c booley
git am .booley/patches/*.patch
```

and one on top of its `adams-bridge` submodule at `2f15ffb1`, the commit
Caliptra pins. Apply it inside the submodule, then record the patched commit
in Caliptra so Booley's baseline checkouts and worktrees use it:

```bash
git -C submodules/adams-bridge switch -c booley
git -C submodules/adams-bridge am "$PWD"/.booley/patches/adams-bridge/*.patch
git commit -m "Point adams-bridge at the Verilator 5.054 fix" submodules/adams-bridge
```

None of them changes RTL behavior. Patches 0001 and 0002 let the registered
firmware tests in `tests.toml` build and pass; 0003 and 0004 let `synth_caliptra`
run and reproduce [`synth/ASIC-REPORT.md`](../synth/ASIC-REPORT.md); 0005 gives
`sim_ecc` its per-operation tests; 0006 lets Verilator 5.054 build
`sim_caliptra` and `lint_caliptra`. Each patch's commit message repeats its
explanation.

As of upstream `main` at `f2d4641c` (2026-11-14), none of these issues is fully
fixed upstream: `main` has the `kv_aes_flow()` return type from 0001 but not
the rest of it, and its `adams-bridge` (`753d4d4c`) still has the code 0006
changes.

## 0001 – Fix firmware test build errors

**Needed for:** `sim`

Every simulation first builds the selected test's firmware. At `e379800c`,
about a dozen registered tests fail to compile or link with GCC 14 or later,
which turns several old C warnings into errors. Booley's RISC-V Sandbox ships
xPack GCC 15.2. Fixes:

- `libs/iccm_hash/iccm_hash.h`: declare `wait_pcr5_ready()`. `iccm_hash.c`
  defines it and the `directed_test_iccm_hash*` tests call it, but no header
  declared it.
- `pv_hash_reset`: define the interrupt-counter struct its ISR header expects,
  and use the renamed `SHA512_GEN_PCR_HASH_NONCE_0` register.
- `smoke_test_hmac_errortrigger`, `smoke_test_kv_ecc_flow1`,
  `smoke_test_kv_ecc_flow2`: these call `srand()` without including
  `<stdlib.h>`, an implicit declaration GCC 14+ rejects. The tests draw from
  `xorshift32()`, so seed it with `xorshift32_init()` instead.
  `smoke_test_kv_crypto_flow2` gets the same seeding change.
- `smoke_test_kv_crypto_flow2`: give ML-DSA key generation a full-size
  private-key buffer instead of a single word passed where an array is expected.
- `smoke_test_kv_ecdh_flow`: add the missing `void` return type to
  `kv_aes_flow()`.
- `smoke_test_hw_config`, `smoke_test_ras`: make
  `service_soc_ifc_notif_intr()` `static inline`. A plain C99 `inline` function
  has no external definition, so any call the compiler does not inline fails to
  link.

Test-only change; no RTL is touched.

## 0002 – Disable OCP lock mode for `directed_kv_enforcement`

**Needed for:** `sim`

The test checks key-vault rules that assume OCP lock mode is off, but its YAML
manifest does not say so. Under the testbench default the test exercises the
wrong rule set and fails. The patch adds `+CLP_OCP_LOCK_DIS` to the manifest's
plusargs, which `scripts/build_firmware.sh` passes to the simulator.

## 0003 – Add a `default` arm to the AXI DMA read-request count case

**Needed for:** `synth`

In `src/axi/rtl/axi_dma_ctrl.sv`, the `rd_req_count_for_payload_next`
`case ... inside` already lists all eight selector values, so a `default` arm is
unreachable and behavior is unchanged. Without it, the Slang frontend used by
Yosys does not recognize the case as full and infers a hold-value combinational
loop, which Booley reports as a critical finding.

This works around a frontend bug,
[povik/sv-elab#387](https://github.com/povik/sv-elab/issues/387). Drop the
patch once that is fixed. Lint stays clean with the patch.

## 0004 – Let synthesis substitute the ECC operand RAM

**Needed for:** `synth`

`src/ecc/rtl/ecc_arith_unit.sv` instantiates `ecc_ram_tdp_file`, a 64x384
dual-port register file. There is no memory macro in this flow, so synthesis
would build it from about 25k flops. The patch adds a hook: when the
`USER_ECC_RAM_TDP` macro is defined, the module it names is instantiated
instead, with the same parameters and ports.

`cores/caliptra_synth.core` defines the macro as
`caliptra_ecc_ram_tdp_timing_surrogate`
([`synth/ecc_ram_tdp_timing_surrogate.sv`](../synth/ecc_ram_tdp_timing_surrogate.sv)),
a synthesis-only stand-in that keeps the RAM's timing endpoints but not its
contents. The macro is undefined everywhere else, so simulation and lint are
unchanged. Without this patch, the RAM is synthesized as flops, so area and
timing differ from `synth/ASIC-REPORT.md`.

## 0005 – Add per-operation tests and cycle reports to the ECC top testbench

**Needed for:** `sim` (`sim_ecc`)

`src/ecc/tb/ecc_top_tb.sv` runs every operation on all 10 vectors in one
test and prints a cycle count per vector. The patch adds:

- `+ECC_NUM_VECTORS=N`: run only the first N vectors (1 to
  `TEST_VECTOR_NUM`; default 10, as before). `sim_ecc`'s Test Variant `one`
  uses it.
- `ECC_TEST=keygen`, `sign`, `verify` or `ecdh`: run that one operation on
  each vector. `otf_reset` is an alias for `ECC_otf_reset_test`. These are
  `sim_ecc`'s Tests.
- One `[SIM_CYCLES] <op> <cycles>` line per operation that ran, after the
  vector loop, with the worst case over the vectors. Booley records it as the
  Test's cycle count; `ECC_normal_test` prints all four lines.

Everything else is unchanged: the common tail (back-to-back commands,
zeroize, fault check) still runs after every test, and the testbench still
exits 0 and reports through `* TESTCASE PASSED` or `* TESTCASE FAILED`.

Test-only change; no RTL is touched.

## 0006 – Size the PISO rate patterns to `NUM_MODES` under Verilator

**Needed for:** `sim` (`sim_caliptra`), `lint` (`lint_caliptra`)

**Applies to:** the `adams-bridge` submodule (`patches/adams-bridge/`)

`src/compress/rtl/compress_top.sv` and `src/decompress/rtl/decompress_top.sv`
instantiate `abr_piso_multi` with `NUM_MODES(4)`, but under
`` `ifdef VERILATOR `` they pass five-element `INPUT_RATES` and `OUTPUT_RATES`
patterns (`'{..., 0}`). That branch worked around an older Verilator
(`adams-bridge` commit `ab4a822`, "Fix verilator build for Caliptra").
Verilator 5.054, which Booley's Sandbox ships, rejects it:

```text
%Error: Assignment pattern with too many elements
```

The patch drops the Verilator-only branch, so every tool gets the
four-element patterns the other tools already use. The fifth element was never
read: `mode` is `$clog2(NUM_MODES)` = 2 bits wide, so it indexes only entries
0 to 3. Behavior is unchanged.
