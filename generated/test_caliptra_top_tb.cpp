// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
#include <stdlib.h>
#include <iostream>
#include <utility>
#include <string>
#include <fstream>
#include <vector>
#include "Vcaliptra_top_tb.h"
#include "verilated.h"
#if VM_TRACE_VCD
#include "verilated_vcd_c.h"
#elif VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

vluint64_t main_time = 0;

double sc_time_stamp () {
 return main_time;
}


int main(int argc, char** argv) {
  std::cout << "\nVerilatorTB: Start of sim\n" << std::endl;

  // The Booley firmware hook writes the selected test's upstream YAML plusargs.
  std::ifstream args_file(".booley_test_plusargs");
  std::vector<std::string> extra_args;
  std::string option;
  while (std::getline(args_file, option)) {
    if (!option.empty()) extra_args.push_back(option);
  }
  std::vector<char*> merged_args(argv, argv + argc);
  for (auto& value : extra_args) merged_args.push_back(value.data());
  Verilated::commandArgs(static_cast<int>(merged_args.size()), merged_args.data());

  Vcaliptra_top_tb* tb = new Vcaliptra_top_tb;

  // init trace dump
#if VM_TRACE
  const std::string trace_arg = Verilated::commandArgsPlusMatch("tracefile=");
  const std::string trace_file = trace_arg.empty() ? "" : trace_arg.substr(std::string("+tracefile=").size());
  Verilated::traceEverOn(true);
  #if VM_TRACE_VCD
    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb->trace (tfp, 24);
    tfp->open (trace_file.empty() ? "sim.vcd" : trace_file.c_str());
  #elif VM_TRACE_FST
    VerilatedFstC* tfp = new VerilatedFstC;
    tb->trace (tfp, 24);
    tfp->open (trace_file.empty() ? "sim.fst" : trace_file.c_str());
  #endif
#endif
  // Simulate
  while(!Verilated::gotFinish()){
#if VM_TRACE
      tfp->dump (main_time);
#endif
      main_time += 1;
      // Toggle every 5ns (timescale precision is 100ps)
      if (main_time % 50 == 0) tb->core_clk = !tb->core_clk;
      tb->eval();
  }

#if VM_TRACE
  tfp->close();
#endif

  std::cout << "\nVerilatorTB: End of sim" << std::endl;
  exit(EXIT_SUCCESS);

}
