"""Generate the Booley variant of upstream's Verilator testbench main.

Reads ``src/integration/tb/test_caliptra_top_tb.cpp`` and writes
``.booley_project/generated/test_caliptra_top_tb.cpp`` with two patches:

1. Per-test plusargs: before ``Verilated::commandArgs`` the main reads
   ``.booley_test_plusargs`` from the run directory (written by
   ``build_firmware.sh`` from the test's YAML manifest) and appends each
   line to argv. Booley launches the simulator without per-test
   arguments, so this file is how a test's runtime switches reach it.
2. Trace destination: ``+tracefile=<path>`` redirects the VCD/FST dump.

Each patch anchors on an exact upstream line and asserts it appears once,
so an upstream edit to those lines fails loudly instead of being skipped.

Rerun after an upstream change to the TB main. From the Caliptra checkout
root:

    python3 .booley_project/scripts/generate_main.py

Standard library only.
"""

from pathlib import Path

# Upstream's argv hand-off, replaced by the plusargs-file merge below.
COMMAND_ARGS_ANCHOR = "  Verilated::commandArgs(argc, argv);"
PLUSARGS_MERGE = """  // The Booley firmware hook writes the selected test's upstream YAML plusargs.
  std::ifstream args_file(".booley_test_plusargs");
  std::vector<std::string> extra_args;
  std::string option;
  while (std::getline(args_file, option)) {
    if (!option.empty()) extra_args.push_back(option);
  }
  std::vector<char*> merged_args(argv, argv + argc);
  for (auto& value : extra_args) merged_args.push_back(value.data());
  Verilated::commandArgs(static_cast<int>(merged_args.size()), merged_args.data());"""

# Booley's trace: true passes +trace +tracefile=<FIFO>; dump there so B-Wave
# streams it. Without +tracefile the dump keeps the stock sim.vcd/sim.fst name.
TRACE_INIT_ANCHOR = "  // init trace dump\n#if VM_TRACE\n"
TRACE_FILE_DECL = """  const std::string trace_arg = Verilated::commandArgsPlusMatch("tracefile=");
  const std::string trace_file = trace_arg.empty() ? "" : trace_arg.substr(std::string("+tracefile=").size());
"""


def replace_once(text: str, old: str, new: str) -> str:
    """Replace the single occurrence of ``old``; assert it occurs exactly once."""
    assert text.count(old) == 1
    return text.replace(old, new, 1)


def main() -> None:
    # The Caliptra checkout: this file lives at <root>/.booley_project/scripts/.
    root = Path(__file__).resolve().parents[2]
    source = root / "src/integration/tb/test_caliptra_top_tb.cpp"
    output = root / ".booley_project/generated/test_caliptra_top_tb.cpp"
    text = source.read_text()

    # Headers for std::ifstream and std::vector used by PLUSARGS_MERGE.
    text = text.replace(
        "#include <string>\n",
        "#include <string>\n#include <fstream>\n#include <vector>\n",
        1,
    )
    text = replace_once(text, COMMAND_ARGS_ANCHOR, PLUSARGS_MERGE)
    text = replace_once(text, TRACE_INIT_ANCHOR, TRACE_INIT_ANCHOR + TRACE_FILE_DECL)
    for ext in ("vcd", "fst"):
        text = replace_once(
            text,
            f'tfp->open ("sim.{ext}");',
            f'tfp->open (trace_file.empty() ? "sim.{ext}" : trace_file.c_str());',
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)
    print(output)


if __name__ == "__main__":
    main()
