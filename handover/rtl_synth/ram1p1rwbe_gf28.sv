// ram1p1rwbe_gf28.sv - SYNTHESIS replacement for uncore_ip/src/generic/mem/ram1p1rwbe.sv
// Same module name, parameters and ports. Two instances in neumann_soc:
//   IRAM  u_uncore.ram.ram.memory   DEPTH 4096 x 32  (16 KB, 0x8000_0000)
//   DRAM  u_dram.memory             DEPTH 2048 x 32  ( 8 KB, 0x8001_0000)
//
// Behaviour the bus logic (ram_ahb.sv) needs = a plain 1-port synchronous SRAM:
//   * address/control sampled at posedge clk, read data valid after that edge
//     (1-cycle read latency); dout must HOLD while no new read happens.
//   * byte write enables bwe[3:0] (bwe[i] -> din[8i+7:8i]); we=1 is a write.
//   * ce is tied 1 by ram_ahb (macro may be enabled every cycle; see note on power).
//   * ram_ahb never reads in the cycle after a write (it stalls), so ANY
//     read-during-write mode of the macro is acceptable.
//   * no reset, no init contents needed (software loads IRAM/DRAM).
//
// +define+NEUMANN_GF28_SRAM -> memory-compiler macros (PD team: put names/pins below)
// no define                  -> behavioural model identical to the RTL (simulation).
module ram1p1rwbe import cvw::*; #(parameter USE_SRAM = 0, DEPTH = 64, WIDTH = 44, PRELOAD_ENABLED = 0) (
  input  logic                     clk,
  input  logic                     ce,
  input  logic [$clog2(DEPTH)-1:0] addr,
  input  logic [WIDTH-1:0]         din,
  input  logic                     we,
  input  logic [(WIDTH-1)/8:0]     bwe,
  output logic [WIDTH-1:0]         dout
);
`ifdef NEUMANN_GF28_SRAM
  // bit-write mask, active high (invert if the macro uses active-low BWEB/WEN)
  logic [WIDTH-1:0] bitmask;
  for (genvar i = 0; i < WIDTH/8; i++) begin : g_mask
    assign bitmask[i*8 +: 8] = {8{bwe[i]}};
  end
  if (DEPTH == 4096 && WIDTH == 32) begin : g_iram
    // TODO(PD): IRAM macro 4096x32 (or 2 x 2048x32 banked on addr[11])
    GF28_SRAM_4096X32 u_mem (.CLK(clk), .CEN(~ce), .WEN(~we), .BWEN(~bitmask),
                             .A(addr), .D(din), .Q(dout));
  end else if (DEPTH == 2048 && WIDTH == 32) begin : g_dram
    // TODO(PD): DRAM macro 2048x32
    GF28_SRAM_2048X32 u_mem (.CLK(clk), .CEN(~ce), .WEN(~we), .BWEN(~bitmask),
                             .A(addr), .D(din), .Q(dout));
  end else begin : g_bad
    $error("ram1p1rwbe_gf28: no macro for DEPTH=%0d WIDTH=%0d", DEPTH, WIDTH);
  end
`else
  // behavioural (same as RTL ram1p1rwbe.sv, USE_SRAM=0 branch)
  bit [WIDTH-1:0] RAM[DEPTH-1:0];
  logic [$clog2(DEPTH)-1:0] addrd;
  flopen #($clog2(DEPTH)) adrreg(clk, ce, addr, addrd);
  assign dout = RAM[addrd];
  always @(posedge clk)
    if (ce & we)
      for (int i = 0; i < WIDTH/8; i++)
        if (bwe[i]) RAM[addr][i*8 +: 8] <= din[i*8 +: 8];
`endif
endmodule
