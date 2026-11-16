// ============================================================
// cluster_clock_gating : clock gate without a latch
//
// The enable is sampled by a flip-flop on the falling edge of clk_i and
// ANDed with clk_i, so clk_o cannot glitch: en_i may change during the high
// phase of clk_i and the gate only reacts at the next falling edge.
// en_i therefore has to be stable half a clock period before the rising
// edge it should open.
//
// GATE_EN = 0 removes the gate completely (clk_o = clk_i, no flop, no AND).
// The top-level parameter CLK_GATING of top_soc / rv32i_core sets it for the
// whole design.
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
  if (GATE_EN) 
  begin 
    logic clk_en;
    always_ff @(negedge clk_i) 
    clk_en <= en_i | test_en_i;
    assign clk_o = clk_i & clk_en;
  end 
  else 
  begin
    assign clk_o = clk_i;
    logic unused_ok;
    assign unused_ok = &{1'b0, en_i, test_en_i};
  end
endmodule
