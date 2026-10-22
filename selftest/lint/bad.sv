// Doctor-only lint fail-path fixture.
module caliptra_lint_selftest_bad (
    input logic clk,
    output logic value
);
  always_ff @(posedge clk) begin
    value <= undeclared_rhs;
  end
endmodule
