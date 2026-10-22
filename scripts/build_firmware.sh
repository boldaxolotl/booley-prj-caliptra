#!/usr/bin/env bash
set -euo pipefail

: "${BOOLEY_TEST_NAME:?BOOLEY_TEST_NAME is required}"
: "${BOOLEY_PROJECT_ROOT:?BOOLEY_PROJECT_ROOT is required}"
: "${BOOLEY_RUN_CWD:?BOOLEY_RUN_CWD is required}"

case "$BOOLEY_TEST_NAME" in
  *[!A-Za-z0-9_]*|'') echo "Invalid test name: $BOOLEY_TEST_NAME" >&2; exit 2 ;;
esac

project_root="$(realpath "$BOOLEY_PROJECT_ROOT")"
run_cwd="$(realpath -m "$BOOLEY_RUN_CWD")"
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

build_dir="$run_cwd/.firmware/$BOOLEY_TEST_NAME"
mkdir -p "$build_dir" "$run_cwd"
make -C "$build_dir" -f "$project_root/tools/scripts/Makefile" \
  CALIPTRA_ROOT="$project_root" \
  TESTNAME="$suite_name" BUILD_CFLAGS=-O2 program.hex

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
