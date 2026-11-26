`timescale 1ns/1ps
// ============================================================================
//  tb_arch - run one riscv-arch-test program on the neumann SoC and dump its signature.
//
//  Back-door preload (before reset):
//    +IRAM=<hex>  32-bit words, one per line, from 0x8000_0000 (entry at +0x80)
//    +DRAM=<hex>  32-bit words, one per line, from DRAM base + 0x40
//  Boot pins gpio_i[31:30] = 01: the boot ROM jumps straight to 0x8000_0080.
//  The test ends with RVMODEL_HALT (env/model_test.h): DRAM +0x00 = 0xC0DE0001,
//  +0x10 / +0x14 = begin / end of the signature (in DRAM).
//  The words begin..end-4 are written to +SIG=<file> (8 hex digits per line,
//  the format of the suite's *.reference_output). The Python runner compares.
//
//  Parameters: CLK_GATING, IRAM_PHYS (0x3FFF = chip size 16 KB; 0x1FFFFF for the
//  big-memory build, together with config_big/config.vh).
//  Plusargs: +MAXCYC=<n> (default 2000000), +NAME=<text>.
// ============================================================================
module tb_arch;
  parameter CLK_GATING = 1;
  parameter [63:0] IRAM_PHYS = 64'h0000_3FFF;

  string iram_file, dram_file, sig_file, name;
  int unsigned max_cyc, cyc = 0, errors = 0;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  always @(posedge clk) cyc++;

  wire        dbg_tx, uart_tx, halted;
  wire [31:0] gpio_o, gpio_oe;
  wire [31:0] gpio_i = {2'b01, 30'b0};          // direct boot
  wire        spi_mosi, spi_sck, sdc_mosi, sdc_sck;
  wire [3:0]  spi_cs, sdc_cs;

  neumann_soc #(.CLK_GATING(CLK_GATING), .IRAM_PHYS_RANGE(IRAM_PHYS)) dut (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0), .fetch_enable_i(1'b1),
    .dbg_rx_i(1'b1), .dbg_tx_o(dbg_tx), .dbg_halted_o(halted),
    .uart_rx_i(1'b1), .uart_tx_o(uart_tx),
    .gpio_i(gpio_i), .gpio_o(gpio_o), .gpio_oe_o(gpio_oe),
    .spi_miso_i(1'b0), .spi_mosi_o(spi_mosi), .spi_cs_o(spi_cs), .spi_sck_o(spi_sck),
    .sdc_miso_i(1'b0), .sdc_mosi_o(sdc_mosi), .sdc_cs_o(sdc_cs), .sdc_sck_o(sdc_sck));

  `define ROM  dut.u_uncore.bootrom.bootrom.memory.ROM
  `define IRAM dut.u_uncore.ram.ram.memory.ram.RAM
  `define DRAM dut.u_dram.memory.ram.RAM
  function automatic logic [31:0] dram(int unsigned byte_off); return `DRAM[byte_off / 4]; endfunction

  // load a word-per-line hex file into one of the memories, starting at word index w0
  function automatic int load(string f, int which, int unsigned w0);
    int fd, n = 0; logic [31:0] w;
    fd = $fopen(f, "r");
    if (fd == 0) begin $display("ERROR: cannot open %s", f); errors++; return 0; end
    while ($fscanf(fd, "%h", w) == 1) begin
      case (which)
        0: `ROM[w0 + n]  = w;
        1: `IRAM[w0 + n] = w;
        default: `DRAM[w0 + n] = w;
      endcase
      n++;
    end
    $fclose(fd);
    return n;
  endfunction

  initial begin
    string rom_file;
    int nrom, ni, nd, fd;
    logic [31:0] b, e;
    if (!$value$plusargs("ROM=%s", rom_file))   rom_file = "sw/boot/rom.hex";
    if (!$value$plusargs("IRAM=%s", iram_file)) iram_file = "";
    if (!$value$plusargs("DRAM=%s", dram_file)) dram_file = "";
    if (!$value$plusargs("SIG=%s", sig_file))   sig_file = "signature.out";
    if (!$value$plusargs("NAME=%s", name))      name = "?";
    if (!$value$plusargs("MAXCYC=%d", max_cyc)) max_cyc = 2000000;
    #1;
    nrom = load(rom_file, 0, 0);
    ni   = load(iram_file, 1, 0);
    nd   = (dram_file != "") ? load(dram_file, 2, 'h40 / 4) : 0;
    $display("%s: ROM %0d, IRAM %0d, DRAM %0d words", name, nrom, ni, nd);
    if (nrom == 0 || ni == 0) begin $display("RESULT: FAIL (empty image)"); max_cyc = 0; end
    repeat (5) @(posedge clk);
    rst_n = (max_cyc != 0);
    while (dram('h00) != 32'hC0DE0001 && cyc < max_cyc) @(posedge clk);
    if (dram('h00) != 32'hC0DE0001) begin
      // (no signature file: the runner reports the test as not finished)
      $display("ERROR: %s did not finish in %0d cycles (SIG_STATUS %08h)", name, max_cyc, dram('h00));
      $display("RESULT: FAIL");
    end else begin
      b = dram('h10); e = dram('h14);
      fd = $fopen(sig_file, "w");
      for (logic [31:0] a = b; a < e; a += 4) $fdisplay(fd, "%08x", dram(a & 32'h0000_FFFF));
      $fclose(fd);
      $display("%s: done at cycle %0d, signature %08h..%08h (%0d words) -> %s",
               name, cyc, b, e, (e - b) / 4, sig_file);
      $display("RESULT: DONE");
    end
    $finish;
  end
endmodule
