// ============================================================
// rv32i_register_file : 31 x DATA_WIDTH flip-flop register file (x0 = 0)
//
// One write port, two combinational read ports. No latches.
//
// Gated version (default): every register has its own clock gate
// (cluster_clock_gating) that opens only when the register is written, so
// the 31 registers are not clocked on the other cycles.
//
// CLK_GATING = 0: no clock gates, plain enable flops.
// ============================================================
module rv32i_register_file
#(
  parameter DATA_WIDTH=32,
  parameter CLK_GATING=1          // 1 = per-register clock gate, 0 = enable flops
)
(
  input clk,
  input rst_n,
  input test_en_i,
  input [4:0] raddr_a_i,
  output [DATA_WIDTH-1:0] rdata_a_o,
  input [4:0] raddr_b_i,
  output [DATA_WIDTH-1:0] rdata_b_o,
  input [4:0] waddr_a_i,
  input [DATA_WIDTH-1:0] wdata_a_i,
  input we_a_i
);
localparam ADDR_WIDTH=5;
localparam NUM_WORDS=2**ADDR_WIDTH;
wire [DATA_WIDTH-1:0] mem [1:NUM_WORDS-1];
wire unused_ok;
// rst_n: the flops are not reset (x0 is hard-wired, software initialises the rest)
// test_en_i: only used by the clock gates
assign unused_ok=&{1'b0,rst_n,(CLK_GATING==0)?test_en_i:1'b0};
wire [NUM_WORDS-1:1] waddr_onehot_a;
wire [ADDR_WIDTH-1:0] raddr_a_int;
wire [ADDR_WIDTH-1:0] raddr_b_int;
wire [ADDR_WIDTH-1:0] waddr_a_int;
genvar x;
assign raddr_a_int=raddr_a_i[ADDR_WIDTH-1:0];
assign raddr_b_int=raddr_b_i[ADDR_WIDTH-1:0];
assign waddr_a_int=waddr_a_i[ADDR_WIDTH-1:0];
assign rdata_a_o=(raddr_a_int==0) ? {DATA_WIDTH{1'b0}} : mem[raddr_a_int];
assign rdata_b_o=(raddr_b_int==0) ? {DATA_WIDTH{1'b0}} : mem[raddr_b_int];

generate
  for(x=1;x<NUM_WORDS;x=x+1)
  begin : g_reg
    assign waddr_onehot_a[x]=we_a_i&(waddr_a_int==x[ADDR_WIDTH-1:0]);
    reg [DATA_WIDTH-1:0] q;
    assign mem[x]=q;
    if(CLK_GATING==0)
    begin : g_en
      always @(posedge clk)
        if(waddr_onehot_a[x])
          q<=wdata_a_i;
    end
    else
    begin : g_cg
    wire mem_clk;
    cluster_clock_gating CG_Inst
    (
      .clk_i(clk),
      .en_i(waddr_onehot_a[x]),
      .test_en_i(test_en_i),
      .clk_o(mem_clk)
    );
    always @(posedge mem_clk)
      q<=wdata_a_i;
    end
  end
endgenerate
endmodule
