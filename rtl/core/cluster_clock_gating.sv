// ============================================================
// cluster_clock_gating : latch-based clock gate (ICG structure)
//
// Standard integrated-clock-gate structure: a latch that is transparent while
// clk_i is low holds the enable, and the latched enable is ANDed with clk_i.
// The latch is closed while clk_i is high, so a change of en_i during the high
// phase cannot cut or extend a clock pulse (no glitch on clk_o).
// en_i must be stable before the rising edge it should let through (setup to
// the latch closing), like the enable of a library ICG cell.
// test_en_i = 1 forces the gate open (scan / DFT).
//
// For implementation replace the body with the GF 28nm library ICG cell
// (same ports: CK = clk_i, E = en_i, SE = test_en_i, GCK = clk_o).
//
// GATE_EN = 0 removes the gate completely (clk_o = clk_i, no latch, no AND).
// The top-level parameter CLK_GATING of neumann_soc / rv32i_core sets it for
// the whole design.
// ============================================================
module cluster_clock_gating
#(
    parameter GATE_EN = 1
)
(
    input  logic clk_i,
    input  logic en_i,
    input  logic test_en_i,
    output logic clk_o
);
  if (GATE_EN) begin : g_gate
    logic clk_en;
    /* verilator lint_off LATCH */
    always_latch
      if (!clk_i) clk_en = en_i | test_en_i;
    /* verilator lint_on LATCH */
    assign clk_o = clk_i & clk_en;
  end
  else begin : g_nogate
    assign clk_o = clk_i;
    logic unused_ok;
    assign unused_ok = &{1'b0, en_i, test_en_i};
  end
endmodule
