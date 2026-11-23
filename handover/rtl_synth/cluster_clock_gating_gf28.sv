// cluster_clock_gating_gf28.sv - SYNTHESIS replacement for rtl/core/cluster_clock_gating.sv
// Same module name, parameter and ports. Used 32x: 1 in rv32i_core (core clock),
// 31 in rv32i_register_file (one per register x1..x31).
//
// +define+NEUMANN_GF28_ICG  -> library ICG cell (PD team: put the GF 28nm cell name and
//                              pin names below; latch-based ICG with scan/test enable).
// no define                  -> same behavioural latch + AND as the RTL (for simulation).
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
`ifdef NEUMANN_GF28_ICG
    // TODO(PD): replace GF28_ICG_CELL and pin names with the GF 28nm library ICG,
    // e.g. a positive-edge latch-based gate with test enable:
    //   CK = clk_i, E = en_i, SE = test_en_i, GCK/Q = clk_o
    GF28_ICG_CELL u_icg (.CK(clk_i), .E(en_i), .SE(test_en_i), .GCK(clk_o));
`else
    logic clk_en;
    always_latch
      if (!clk_i) clk_en = en_i | test_en_i;
    assign clk_o = clk_i & clk_en;
`endif
  end
  else begin : g_nogate
    assign clk_o = clk_i;
  end
endmodule
