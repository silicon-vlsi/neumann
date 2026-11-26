`timescale 1ns/1ps
// ============================================================================
//  spi_mem - simple SPI slave memory for simulation (mode 0: CPOL = 0, CPHA = 0).
//  256 bytes. Commands (first byte after CS falls), then a 1-byte address:
//    0x02 addr d0 d1 ...   write, address increments
//    0x03 addr -> d0 d1 ... read,  address increments
//  MOSI is sampled on the rising SCK edge, MISO changes on the falling edge (the first
//  data bit is driven on the falling edge that ends the address byte).
//  Counts bytes written / read for the log.
// ============================================================================
module spi_mem (
  input  logic cs_n,
  input  logic sck,
  input  logic mosi,
  output logic miso
);
  logic [7:0] mem [0:255];
  logic [7:0] sr, out_sr, addr, cmd;
  int         bits, idx, n_wr = 0, n_rd = 0;   // n_rd counts bytes loaded for sending

  initial begin
    for (int i = 0; i < 256; i++) mem[i] = 8'hFF;
    miso = 1'b0;
  end

  always @(negedge cs_n) begin bits = 0; idx = 0; out_sr = 8'h00; end

  always @(posedge sck) if (!cs_n) begin
    sr = {sr[6:0], mosi};
    bits++;
    if (bits == 8) begin
      bits = 0;
      if (idx == 0) cmd = sr;
      else begin
        if (idx == 1) addr = sr;
        else if (cmd == 8'h02) begin mem[addr] = sr; addr++; n_wr++; end
        if (cmd == 8'h03) begin out_sr = mem[addr]; addr++; n_rd++; end   // next byte to send
      end
      idx++;
    end
  end

  always @(negedge sck) if (!cs_n) begin
    miso   = out_sr[7];
    out_sr = {out_sr[6:0], 1'b0};
  end
endmodule
