// SPDX-License-Identifier: Apache-2.0
//
// Verilator C++ main for the block-level ECC testbench (Target sim_ecc).
//
// ecc_top_tb generates its own clock and drives every test from initial
// blocks, so this main only advances time (--timing scheduling) until the
// testbench calls $finish. Verilator's auto --main would do the same, but it
// cannot trace and has no coverage hook; this main adds both:
//   - Tracing: Booley's trace run passes +tracefile=<path>; without it the
//     dump goes to sim.vcd / sim.fst.
//   - Coverage: Booley's coverage build defines VM_COVERAGE and links
//     booley_coverage.h; the database is written once, after $finish
//     (custom_main_hooks: [write_hook] in cores/caliptra_ecc.core).
#if VM_COVERAGE
#include "booley_coverage.h"
#endif
#include <cstdlib>
#include <iostream>
#include <memory>
#include <string>

#include "Vecc_top_tb.h"
#include "verilated.h"
#if VM_TRACE_VCD
#include "verilated_vcd_c.h"
#elif VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

int main(int argc, char** argv) {
  const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
  contextp->commandArgs(argc, argv);
  const std::unique_ptr<Vecc_top_tb> tb{new Vecc_top_tb{contextp.get(), "TOP"}};

#if VM_TRACE
  const std::string trace_arg = contextp->commandArgsPlusMatch("tracefile=");
  const std::string trace_file =
      trace_arg.empty() ? "" : trace_arg.substr(std::string("+tracefile=").size());
  contextp->traceEverOn(true);
#if VM_TRACE_VCD
  VerilatedVcdC* tfp = new VerilatedVcdC;
  tb->trace(tfp, 24);
  tfp->open(trace_file.empty() ? "sim.vcd" : trace_file.c_str());
#elif VM_TRACE_FST
  VerilatedFstC* tfp = new VerilatedFstC;
  tb->trace(tfp, 24);
  tfp->open(trace_file.empty() ? "sim.fst" : trace_file.c_str());
#endif
#endif

  // Event-driven loop for --timing: evaluate, dump, then jump to the next
  // scheduled time slot. Stops at $finish or when nothing is left to run.
  while (!contextp->gotFinish()) {
    tb->eval();
#if VM_TRACE
    tfp->dump(contextp->time());
#endif
    if (!tb->eventsPending()) break;
    contextp->time(tb->nextTimeSlot());
  }
  tb->final();

#if VM_TRACE
  tfp->close();
  delete tfp;
#endif

#if VM_COVERAGE
  booley_coverage_write();
#endif
  if (!contextp->gotFinish()) {
    std::cerr << "ecc_top_tb: simulation ran out of events before $finish" << std::endl;
  }
  return EXIT_SUCCESS;
}
