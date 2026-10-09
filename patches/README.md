# Caliptra patches

This project needs four small commits on top of Caliptra RTL commit
[`e379800c`](https://github.com/chipsalliance/caliptra-rtl/commit/e379800c5467379386f96a9a51a539bd662b608a).
Apply them from the Caliptra checkout root:

```bash
git switch -c booley
git am .booley_project/patches/*.patch
```

None of them changes RTL behavior. Patches 0001 and 0002 let the registered
firmware tests in `tests.toml` build and pass; 0003 and 0004 let `synth_caliptra`
run and reproduce [`synth/ASIC-REPORT.md`](../synth/ASIC-REPORT.md). Each patch's
commit message repeats its explanation.

As of upstream `main` at `7b901d59` (2026-10-08), none of these issues is fixed
upstream.

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
