module cluster_clock_gating
(
    input  clk_i,
    input  en_i,
    input  test_en_i,
    output clk_o
);
reg clk_en;
always @(*) 
begin
  if(clk_i==1'b0)
    clk_en=en_i|test_en_i;
end
assign clk_o=clk_i&clk_en;
endmodule
