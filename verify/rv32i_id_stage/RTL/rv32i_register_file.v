module rv32i_register_file
#(
  parameter RV32E=0,
  parameter DATA_WIDTH=32
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
localparam ADDR_WIDTH=RV32E?4:5;
localparam NUM_WORDS=2**ADDR_WIDTH;
reg [DATA_WIDTH-1:0] mem [0:NUM_WORDS-1];
reg [NUM_WORDS-1:1] waddr_onehot_a;
wire [NUM_WORDS-1:1] mem_clocks;
reg [DATA_WIDTH-1:0] wdata_a_q;
wire [ADDR_WIDTH-1:0] raddr_a_int;
wire [ADDR_WIDTH-1:0] raddr_b_int;
wire [ADDR_WIDTH-1:0] waddr_a_int;
assign raddr_a_int=raddr_a_i[ADDR_WIDTH-1:0];
assign raddr_b_int=raddr_b_i[ADDR_WIDTH-1:0];
assign waddr_a_int=waddr_a_i[ADDR_WIDTH-1:0];
wire clk_int;
integer i;
integer k;
genvar x;
assign rdata_a_o=mem[raddr_a_int];
assign rdata_b_o=mem[raddr_b_int];
cluster_clock_gating CG_WE_GLOBAL
(
  .clk_i(clk),
  .en_i(we_a_i),
  .test_en_i(test_en_i),
  .clk_o(clk_int)
);
always @(posedge clk_int or negedge rst_n) 
begin
  if(~rst_n)
    wdata_a_q<={DATA_WIDTH{1'b0}};
  else if(we_a_i)
    wdata_a_q<=wdata_a_i;
end
always @(*) 
begin
  for(i=1;i<NUM_WORDS;i=i+1) 
  begin
    if((we_a_i==1'b1)&&(waddr_a_int==i))
      waddr_onehot_a[i]=1'b1;
    else
      waddr_onehot_a[i]=1'b0;
  end
end
generate
  for(x=1;x<NUM_WORDS;x=x+1) 
  begin
    cluster_clock_gating CG_Inst
    (
      .clk_i(clk_int),
      .en_i(waddr_onehot_a[x]),
      .test_en_i(test_en_i),
      .clk_o(mem_clocks[x])
    );
  end
endgenerate
always @(*) 
begin
  mem[0]={DATA_WIDTH{1'b0}};
  for(k=1;k<NUM_WORDS;k=k+1) 
  begin
    if(mem_clocks[k]==1'b1)
      mem[k]=wdata_a_q;
  end
end
endmodule
//Area, power, timming sdk
