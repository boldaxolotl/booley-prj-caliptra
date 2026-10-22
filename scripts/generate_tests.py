from pathlib import Path
import re
import yaml

root = Path(__file__).resolve().parents[2]
suite_root = root / 'src/integration/test_suites'
l0 = (root / 'src/integration/stimulus/L0_regression.yml').read_text()
ci_paths = [path for item in yaml.safe_load(l0)['contents'] for suite in item.values() for path in suite.get('paths', [])]
ci = list(dict.fromkeys(re.search(r'\.\./test_suites/([^/]+)/', path).group(1) for path in ci_paths))
excluded = {
    'smoke_test_clk_gating', 'smoke_test_cg_wdt',
    'smoke_test_mbox_cg', 'smoke_test_kv_cg',
    'smoke_test_doe_cg', 'smoke_test_dma',
}
unqualified_reasons = {
    'caliptra_demo': (
        'Firmware build fails on removed HMAC384 registers and the obsolete '
        'PCR-as-HMAC-key control.'
    ),
    'infinite_loop': 'Requires external control and has no standalone completion.',
    'jtag_tap_mbox': 'Requires external control and has no standalone completion.',
    'smoke_test_dma_aes_gcm_collision_test': (
        'Native and Booley runs fail after an unexpected DMA NMI precedes the '
        'expected CIF error status.'
    ),
    'smoke_test_ras': (
        'Native and Booley runs fail with tests 4-11 incomplete and a bad '
        'generic-input toggle.'
    ),
    'smoke_test_mldsa_externalmu_keygen_sign_vfy_rand': (
        'Verilator compiles out the required upstream MLDSA injection; '
        'firmware observes VERIFY_PASS=0.'
    ),
    'smoke_test_mldsa_keygen_sign_vfy_rand': (
        'Verilator compiles out the required upstream MLDSA injection; '
        'firmware observes VERIFY_PASS=0.'
    ),
    'smoke_test_mldsa_keygen_standalone_sign_vfy_rand': (
        'Verilator compiles out the required upstream MLDSA injection; '
        'firmware observes VERIFY_PASS=0.'
    ),
    'directed_doe_scan': (
        'Reaches a pass sentinel but emits 1,530,247 SVA diagnostics; quarantined.'
    ),
    'directed_fsm_glitch_inject': (
        'Verilator compiles out the upstream 0x95 glitch handler, so the test '
        'waits indefinitely.'
    ),
    'randomized_mlkem_kv': (
        'Native and Booley runs both time out after the MLKEM keygen command.'
    ),
    'randomized_pcr_ecc_signing': (
        'Native and Booley runs both time out after ECC PCR SIGNING.'
    ),
    'smoke_test_mldsa_locked_api': (
        'Native and Booley runs both time out during MLDSA keygen and signing.'
    ),
    'smoke_test_mldsa_zeroize': (
        'Native and Booley runs both time out during MLDSA keygen and signing.'
    ),
    'smoke_test_mlkem_kv_ocp_progress': (
        'Native and Booley runs both time out after the MLKEM keygen command.'
    ),
    'smoke_test_mlkem_locked_api': (
        'Native and Booley runs both time out after the MLKEM keygen command.'
    ),
}
all_tests = {p.stem for p in suite_root.glob('*/*.yml')}
ordered = ['iccm_lock']
ordered += [name for name in ci if name not in excluded and name != 'iccm_lock']
ordered += sorted(all_tests - set(ordered) - excluded)
assert len(all_tests) == 197 and len(ordered) == 191
candidate_order = ordered
unqualified = [name for name in candidate_order if name in unqualified_reasons]
assert set(unqualified) == set(unqualified_reasons)
ordered = [name for name in candidate_order if name not in unqualified_reasons]
assert len(ordered) == 175

out = root / '.booley_project/tests.toml'
lines = [
    '[sim_caliptra]',
    '# Qualified Caliptra YAML suites, including portable DMA AES KV variants.',
    '# Assertion caveat: nine registered tests pass but emit unresolved upstream SVA diagnostics.',
    '# iccm_lock: IccmFetchWithoutLock_A (1).',
    '# directed_kv_debug_scan_bypass (16), directed_kv_glitch_inject (24),',
    '# smoke_test_kv_parallel_access (24), smoke_test_wdt (24), and smoke_test_wdt_rst (24):',
    '# key-vault debug-flush mismatches.',
    '# directed_kv_iccm_region (17): key-vault flush (15) and boot-flow monotonicity (2).',
    '# directed_kv_monitor_neg (352): key-vault flush/comprehensive failures during fault injection.',
    '# smoke_test_kv_boot_flow_monitor (2): FMC/RT boot-flow monotonicity.',
    '# Passing firmware sentinels do not waive these assertion failures.',
    'select = "+CLP_REGRESSION"',
    'tests = [',
]
lines += [f'  "{name}",' for name in ordered]
lines += [
    '',
    '  # Unqualified candidates retained for visibility. Uncomment only after',
    '  # the stated native/Booley blocker is resolved and the test passes.',
]
for name in unqualified:
    lines += [
        f'  # {unqualified_reasons[name]}',
        f'  # "{name}",',
    ]
lines += [']', '']
out.write_text('\n'.join(lines))
print(f'{out}: {len(ordered)} registered tests; {len(excluded)} upstream Verilator exclusions')
