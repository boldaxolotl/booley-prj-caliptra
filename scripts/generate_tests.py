"""Generate ``tests.toml``, the Booley test registry for ``sim_caliptra``.

Each upstream test is a YAML manifest at
``src/integration/test_suites/<suite>/<test>.yml``; the test name is the YAML
stem (a suite directory may hold several variants, see build_firmware.sh).
The registry lists, in order:

1. ``iccm_lock`` first: Doctor's deep check smoke-runs the first test.
2. The tests from upstream's L0 regression
   (``src/integration/stimulus/L0_regression.yml``), in CI order.
3. Every other test in the suite directory, alphabetically.

Tests that upstream's own Verilator CI excludes are dropped. Tests known to
fail or hang (UNQUALIFIED_REASONS) stay in the file as commented entries,
each with its blocker, so they remain visible.

Rerun after an upstream test-manifest change (tests added, removed, or
renamed, or an L0 regression list edit). From the Caliptra checkout root:

    python3 .booley_project/scripts/generate_tests.py

Requires PyYAML.
"""

import re
from pathlib import Path

import yaml

# Tests excluded from upstream's Verilator L0 CI
# (.github/workflows/build-test-verilator.yml EXCLUDE_TESTS). Upstream also
# excludes smoke_test_wdt_rst; it stays registered here because it reaches
# its pass sentinel (see the assertion caveat in the generated header).
EXCLUDED = {
    "smoke_test_clk_gating",
    "smoke_test_cg_wdt",
    "smoke_test_mbox_cg",
    "smoke_test_kv_cg",
    "smoke_test_doe_cg",
    "smoke_test_dma",
}

# Tests that do not pass on the pinned Caliptra revision, with the observed
# blocker. "Native" runs use upstream's own Verilator build, so a failure in
# both is not Booley-specific. Emitted commented-out in tests.toml.
UNQUALIFIED_REASONS = {
    "caliptra_demo": (
        "Firmware build fails on removed HMAC384 registers and the obsolete "
        "PCR-as-HMAC-key control."
    ),
    "infinite_loop": "Requires external control and has no standalone completion.",
    "jtag_tap_mbox": "Requires external control and has no standalone completion.",
    "smoke_test_dma_aes_gcm_collision_test": (
        "Native and Booley runs fail after an unexpected DMA NMI precedes the "
        "expected CIF error status."
    ),
    "smoke_test_ras": (
        "Native and Booley runs fail with tests 4-11 incomplete and a bad "
        "generic-input toggle."
    ),
    "smoke_test_mldsa_externalmu_keygen_sign_vfy_rand": (
        "Verilator compiles out the required upstream MLDSA injection; "
        "firmware observes VERIFY_PASS=0."
    ),
    "smoke_test_mldsa_keygen_sign_vfy_rand": (
        "Verilator compiles out the required upstream MLDSA injection; "
        "firmware observes VERIFY_PASS=0."
    ),
    "smoke_test_mldsa_keygen_standalone_sign_vfy_rand": (
        "Verilator compiles out the required upstream MLDSA injection; "
        "firmware observes VERIFY_PASS=0."
    ),
    "directed_doe_scan": (
        "Reaches a pass sentinel but emits 1,530,247 SVA diagnostics; quarantined."
    ),
    "directed_fsm_glitch_inject": (
        "Verilator compiles out the upstream 0x95 glitch handler, so the test "
        "waits indefinitely."
    ),
    "randomized_mlkem_kv": (
        "Native and Booley runs both time out after the MLKEM keygen command."
    ),
    "randomized_pcr_ecc_signing": (
        "Native and Booley runs both time out after ECC PCR SIGNING."
    ),
    "smoke_test_mldsa_locked_api": (
        "Native and Booley runs both time out during MLDSA keygen and signing."
    ),
    "smoke_test_mldsa_zeroize": (
        "Native and Booley runs both time out during MLDSA keygen and signing."
    ),
    "smoke_test_mlkem_kv_ocp_progress": (
        "Native and Booley runs both time out after the MLKEM keygen command."
    ),
    "smoke_test_mlkem_locked_api": (
        "Native and Booley runs both time out after the MLKEM keygen command."
    ),
}

# Pin the tested Caliptra revision: if upstream adds or removes tests, these
# counts change and the run fails loudly instead of silently drifting.
EXPECTED_ALL_TESTS = 197  # YAML manifests under test_suites/
EXPECTED_CANDIDATES = 191  # after the upstream Verilator exclusions
EXPECTED_REGISTERED = 175  # after removing the unqualified tests

# Header for the generated [sim_caliptra] section. The assertion caveat
# records SVA diagnostics seen on the pinned revision (counts in parentheses).
HEADER_LINES = [
    "[sim_caliptra]",
    "# Qualified Caliptra YAML suites, including portable DMA AES KV variants.",
    "# Assertion caveat: nine registered tests pass but emit unresolved upstream SVA diagnostics.",
    "# iccm_lock: IccmFetchWithoutLock_A (1).",
    "# directed_kv_debug_scan_bypass (16), directed_kv_glitch_inject (24),",
    "# smoke_test_kv_parallel_access (24), smoke_test_wdt (24), and smoke_test_wdt_rst (24):",
    "# key-vault debug-flush mismatches.",
    "# directed_kv_iccm_region (17): key-vault flush (15) and boot-flow monotonicity (2).",
    "# directed_kv_monitor_neg (352): key-vault flush/comprehensive failures during fault injection.",
    "# smoke_test_kv_boot_flow_monitor (2): FMC/RT boot-flow monotonicity.",
    "# Passing firmware sentinels do not waive these assertion failures.",
    'select = "+CLP_REGRESSION"',
    "tests = [",
]


def l0_suite_order(root: Path) -> list[str]:
    """Return the suite names in upstream's L0 regression, in CI order."""
    l0 = (root / "src/integration/stimulus/L0_regression.yml").read_text()
    ci_paths = [
        path
        for item in yaml.safe_load(l0)["contents"]
        for suite in item.values()
        for path in suite.get("paths", [])
    ]
    # Paths look like ../test_suites/<suite>/<suite>.yml; keep <suite>.
    return list(
        dict.fromkeys(
            re.search(r"\.\./test_suites/([^/]+)/", path).group(1) for path in ci_paths
        )
    )


def main() -> None:
    # The Caliptra checkout: this file lives at <root>/.booley_project/scripts/.
    root = Path(__file__).resolve().parents[2]
    suite_root = root / "src/integration/test_suites"
    ci = l0_suite_order(root)
    # Test names are YAML stems, so the DMA AES KV variants
    # (smoke_test_dma_aes_kv_{short,large,no_ocp_lock}) register individually;
    # build_firmware.sh maps them back to their shared suite directory.
    all_tests = {p.stem for p in suite_root.glob("*/*.yml")}
    # iccm_lock goes first: Doctor's deep check smoke-runs the first test.
    ordered = ["iccm_lock"]
    ordered += [name for name in ci if name not in EXCLUDED and name != "iccm_lock"]
    ordered += sorted(all_tests - set(ordered) - EXCLUDED)
    assert len(all_tests) == EXPECTED_ALL_TESTS and len(ordered) == EXPECTED_CANDIDATES
    candidate_order = ordered
    unqualified = [name for name in candidate_order if name in UNQUALIFIED_REASONS]
    # Every blocker entry must name a real candidate; a stale entry (renamed or
    # removed upstream test) fails here.
    assert set(unqualified) == set(UNQUALIFIED_REASONS)
    ordered = [name for name in candidate_order if name not in UNQUALIFIED_REASONS]
    assert len(ordered) == EXPECTED_REGISTERED

    out = root / ".booley_project/tests.toml"
    lines = list(HEADER_LINES)
    lines += [f'  "{name}",' for name in ordered]
    lines += [
        "",
        "  # Unqualified candidates retained for visibility. Uncomment only after",
        "  # the stated native/Booley blocker is resolved and the test passes.",
    ]
    for name in unqualified:
        lines += [
            f"  # {UNQUALIFIED_REASONS[name]}",
            f'  # "{name}",',
        ]
    lines += ["]", ""]
    out.write_text("\n".join(lines))
    print(
        f"{out}: {len(ordered)} registered tests; {len(EXCLUDED)} upstream Verilator exclusions"
    )


if __name__ == "__main__":
    main()
