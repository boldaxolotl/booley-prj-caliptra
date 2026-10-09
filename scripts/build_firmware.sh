#!/usr/bin/env bash
# Build and stage the firmware for one Caliptra simulation test.
#
# Called by Booley before each sim run, via booley.toml:
#   [flows.sim].pre_run_commands = ['bash "$BOOLEY_PROJECT_DIR/scripts/build_firmware.sh"']
#
# Environment (set by Booley):
#   BOOLEY_TEST_NAME     test to run: a YAML manifest stem from tests.toml
#   BOOLEY_PROJECT_ROOT  the Caliptra checkout (not .booley_project)
#   BOOLEY_RUN_CWD       directory the simulator runs in ([flows.sim].run_cwd)
#
# Outputs in BOOLEY_RUN_CWD:
#   program.hex dccm.hex iccm.hex mailbox.hex  memory images the TB loads;
#                                              empty when the build has none
#   .booley_test_plusargs                      the test's YAML plusargs, one per
#                                              line, read by the patched TB main
#                                              (see generate_main.py)
#   .firmware/<test>/                          build tree from upstream's Makefile
#
# Needs the upstream firmware toolchain (RISC-V GCC, make), readelf, and
# python3 with PyYAML.
set -euo pipefail

: "${BOOLEY_TEST_NAME:?BOOLEY_TEST_NAME is required}"
: "${BOOLEY_PROJECT_ROOT:?BOOLEY_PROJECT_ROOT is required}"
: "${BOOLEY_RUN_CWD:?BOOLEY_RUN_CWD is required}"

# The name becomes a path component and a make variable; allow only
# identifier characters.
case "$BOOLEY_TEST_NAME" in
  *[!A-Za-z0-9_]*|'') echo "Invalid test name: $BOOLEY_TEST_NAME" >&2; exit 2 ;;
esac

project_root="$(realpath "$BOOLEY_PROJECT_ROOT")"
run_cwd="$(realpath -m "$BOOLEY_RUN_CWD")"
# Most tests live in a suite directory of the same name. The DMA AES KV
# variants are extra YAML manifests (different plusargs) inside the
# smoke_test_dma_aes_kv suite and share its firmware.
suite_name="$BOOLEY_TEST_NAME"
case "$BOOLEY_TEST_NAME" in
  smoke_test_dma_aes_kv_no_ocp_lock|smoke_test_dma_aes_kv_large|smoke_test_dma_aes_kv_short)
    suite_name=smoke_test_dma_aes_kv ;;
esac
test_dir="$project_root/src/integration/test_suites/$suite_name"
if [[ ! -d "$test_dir" ]]; then
  echo "Test suite missing: $test_dir" >&2
  exit 2
fi

# Build with upstream's firmware Makefile, out of tree, one dir per test.
build_dir="$run_cwd/.firmware/$BOOLEY_TEST_NAME"
mkdir -p "$build_dir" "$run_cwd"
make -C "$build_dir" -f "$project_root/tools/scripts/Makefile" \
  CALIPTRA_ROOT="$project_root" \
  TESTNAME="$suite_name" BUILD_CFLAGS=-O2 program.hex

# Copy each image the TB may load. A missing image is replaced by an empty
# file so a stale one from a previous test is never picked up.
for image in program.hex dccm.hex iccm.hex mailbox.hex; do
  if [[ -f "$build_dir/$image" ]]; then
    cp -f "$build_dir/$image" "$run_cwd/$image"
  else
    : > "$run_cwd/$image"
  fi
done

# Precompiled Rust ELFs place .data at a DCCM VMA but give it a ROM LMA.
# The upstream objcopy rule subtracts the DCCM base from that ROM LMA,
# producing an out-of-range @ address. Normalize only those ELF images.
# The fix applies only when the suite ships a prebuilt ELF named after the
# suite and dccm.hex starts at or above 0x40000 (past the 256 KiB DCCM); the
# first @ address is then recomputed as .data VMA - 0x50000000 (DCCM base).
if [[ -f "$test_dir/$suite_name" && -s "$run_cwd/dccm.hex" ]]; then
  python3 - "$test_dir/$suite_name" "$run_cwd/dccm.hex" <<'PYDCCM'
from pathlib import Path
import re
import subprocess
import sys

elf, image = Path(sys.argv[1]), Path(sys.argv[2])
lines = image.read_text().splitlines()
if lines and lines[0].startswith('@') and int(lines[0][1:], 16) >= 0x40000:
    sections = subprocess.run(
        ['readelf', '-SW', str(elf)], check=True, capture_output=True, text=True
    ).stdout
    match = re.search(r'\]\s+\.data\s+\S+\s+([0-9a-fA-F]+)\s+', sections)
    if not match:
        raise SystemExit(f'Missing .data section in {elf}')
    offset = int(match.group(1), 16) - 0x50000000
    if not 0 <= offset < 0x40000:
        raise SystemExit(f'DCCM .data address out of range in {elf}: {offset:#x}')
    lines[0] = f'@{offset:08X}'
    image.write_text('\n'.join(lines) + '\n')
PYDCCM
fi

echo "Staged firmware for $BOOLEY_TEST_NAME in $run_cwd"

# Preserve per-test runtime switches from the upstream playbook manifest.
# Read from the test's own YAML (not the suite's), so DMA AES KV variants keep
# their distinct plusargs. Each must be a single whitespace-free +arg.
python3 - "$test_dir/$BOOLEY_TEST_NAME.yml" "$run_cwd/.booley_test_plusargs" <<'PYARGS'
from pathlib import Path
import sys
import yaml
manifest = yaml.safe_load(Path(sys.argv[1]).read_text()) or {}
args = manifest.get('plusargs', []) or []
if not isinstance(args, list) or any(
    not isinstance(arg, str) or not arg.startswith('+') or any(ch.isspace() for ch in arg)
    for arg in args
):
    raise SystemExit('Invalid upstream test plusargs')
Path(sys.argv[2]).write_text(''.join(arg + '\n' for arg in args))
PYARGS
