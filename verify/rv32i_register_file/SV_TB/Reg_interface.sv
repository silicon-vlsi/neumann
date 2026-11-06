interface Reg_interface
#(
  parameter DATA_WIDTH=32
)
(
  input clk
);
logic rst_n;
logic test_en_i;
logic [4:0] raddr_a_i;
logic [DATA_WIDTH-1:0] rdata_a_o;
logic [4:0] raddr_b_i;
logic [DATA_WIDTH-1:0] rdata_b_o;
logic [4:0] waddr_a_i;
logic [DATA_WIDTH-1:0] wdata_a_i;
logic we_a_i;

clocking drv_cb @(posedge clk);
  default input #1step output #1;
  output rst_n;
  output test_en_i;
  output raddr_a_i;
  output raddr_b_i;
  output waddr_a_i;
  output wdata_a_i;
  output we_a_i;
  input  rdata_a_o;
  input  rdata_b_o;
endclocking

clocking mon_cb @(posedge clk);
  default input #1step;
  input rst_n;
  input test_en_i;
  input raddr_a_i;
  input rdata_a_o;
  input raddr_b_i;
  input rdata_b_o;
  input waddr_a_i;
  input wdata_a_i;
  input we_a_i;
endclocking

modport DUT
(
  input  clk,
  input  rst_n,
  input  test_en_i,
  input  raddr_a_i,
  output rdata_a_o,
  input  raddr_b_i,
  output rdata_b_o,
  input  waddr_a_i,
  input  wdata_a_i,
  input  we_a_i
);

modport DRV (clocking drv_cb, input clk);
modport MON (clocking mon_cb, input clk);

endinterface
