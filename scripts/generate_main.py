from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = root / 'src/integration/tb/test_caliptra_top_tb.cpp'
output = root / '.booley_project/generated/test_caliptra_top_tb.cpp'
text = source.read_text()
text = text.replace('#include <string>\n', '#include <string>\n#include <fstream>\n#include <vector>\n', 1)
old = '  Verilated::commandArgs(argc, argv);'
new = '''  // The Booley firmware hook writes the selected test's upstream YAML plusargs.
  std::ifstream args_file(".booley_test_plusargs");
  std::vector<std::string> extra_args;
  std::string option;
  while (std::getline(args_file, option)) {
    if (!option.empty()) extra_args.push_back(option);
  }
  std::vector<char*> merged_args(argv, argv + argc);
  for (auto& value : extra_args) merged_args.push_back(value.data());
  Verilated::commandArgs(static_cast<int>(merged_args.size()), merged_args.data());'''
assert text.count(old) == 1
text = text.replace(old, new, 1)
# Booley's trace: true passes +trace +tracefile=<FIFO>; dump there so B-Wave
# streams it. Without +tracefile the dump keeps the stock sim.vcd/sim.fst name.
trace_file = '''  const std::string trace_arg = Verilated::commandArgsPlusMatch("tracefile=");
  const std::string trace_file = trace_arg.empty() ? "" : trace_arg.substr(std::string("+tracefile=").size());
'''
old = '  // init trace dump\n#if VM_TRACE\n'
assert text.count(old) == 1
text = text.replace(old, old + trace_file, 1)
for ext in ('vcd', 'fst'):
    old = f'tfp->open ("sim.{ext}");'
    assert text.count(old) == 1
    text = text.replace(old, f'tfp->open (trace_file.empty() ? "sim.{ext}" : trace_file.c_str());', 1)
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(text)
print(output)
