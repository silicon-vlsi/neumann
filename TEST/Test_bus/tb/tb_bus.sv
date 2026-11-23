`timescale 1ns/1ps
// ============================================================================
//  tb_bus - bus corner cases on the neumann SoC (program: programs/bus.c).
//
//  Back-door preload (+ROM, +IRAM from 0x8000_0000, +DRAM from 0x8001_0040), boot pins
//  gpio_i[31:30] = 01 (direct boot). Debug UART at DBG_BIT clocks per bit.
//
//  Three-master part: when the program writes 0x5741 to DRAM 0x8001_0020 (its copy /
//  checksum loop is running), this testbench acts as the host PC on the debug link,
//  without halting the core:
//    - WMEM 64 words to 0x8001_1000 + 4i (value 0xDB000000 | (i * 0x010101 & 0xFFFFFF))
//    - every 8th word also RMEM an IRAM word and compare it with the back-door copy
//    - WMEM 0x8001_0024 = 0xD0E  -> the program leaves its loop and checks the 64 words
//  So instruction fetch (IFU), the core's loads / stores (LSU) and the debug unit (DBG)
//  all use the AHB at the same time.
//  Check: SIG_STATUS = 0xC0DE0001, results = +GOLDEN, debug read-backs all equal.
//  Plusargs: +MAXCYC=<n> (default 3000000), +NAME=<text>.
// ============================================================================
module tb_bus;
  parameter CLK_GATING = 1;
  localparam DBG_BIT = 16;

  string rom_file, iram_file, dram_file, golden_file, name;
  int unsigned max_cyc, cyc = 0, errors = 0;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  always @(posedge clk) cyc++;

  logic        dbg_rx = 1;
  wire         dbg_tx, uart_tx, halted;
  wire  [31:0] gpio_o, gpio_oe;
  wire  [31:0] gpio_i = {2'b01, 30'b0};
  wire         spi_mosi, spi_sck, sdc_mosi, sdc_sck;
  wire  [3:0]  spi_cs, sdc_cs;

  neumann_soc #(.CLK_GATING(CLK_GATING), .DBG_CLKS_PER_BIT(DBG_BIT)) dut (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0), .fetch_enable_i(1'b1),
    .dbg_rx_i(dbg_rx), .dbg_tx_o(dbg_tx), .dbg_halted_o(halted),
    .uart_rx_i(1'b1), .uart_tx_o(uart_tx),
    .gpio_i(gpio_i), .gpio_o(gpio_o), .gpio_oe_o(gpio_oe),
    .spi_miso_i(1'b0), .spi_mosi_o(spi_mosi), .spi_cs_o(spi_cs), .spi_sck_o(spi_sck),
    .sdc_miso_i(1'b0), .sdc_mosi_o(sdc_mosi), .sdc_cs_o(sdc_cs), .sdc_sck_o(sdc_sck));

  `define ROM  dut.u_uncore.bootrom.bootrom.memory.ROM
  `define IRAM dut.u_uncore.ram.ram.memory.ram.RAM
  `define DRAM dut.u_dram.memory.ram.RAM
  function automatic logic [31:0] dram(int unsigned byte_off); return `DRAM[byte_off / 4]; endfunction

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

  // ---------------------------------------------------------------- debug link (host side)
  logic [7:0] dbg_rxq [$];
  initial forever begin
    logic [7:0] c;
    do @(posedge clk); while (dbg_tx !== 1'b0);
    repeat (DBG_BIT / 2 - 1) @(posedge clk);
    if (dbg_tx == 0) begin
      for (int b = 0; b < 8; b++) begin repeat (DBG_BIT) @(posedge clk); c[b] = dbg_tx; end
      repeat (DBG_BIT) @(posedge clk);
      dbg_rxq.push_back(c);
    end
  end
  task automatic dsend(logic [7:0] c);
    dbg_rx = 0; repeat (DBG_BIT) @(posedge clk);
    for (int b = 0; b < 8; b++) begin dbg_rx = c[b]; repeat (DBG_BIT) @(posedge clk); end
    dbg_rx = 1; repeat (DBG_BIT) @(posedge clk);
  endtask
  task automatic drecv(output logic [7:0] c);
    int t = 0;
    while (dbg_rxq.size() == 0 && t < 20000) begin @(posedge clk); t++; end
    if (dbg_rxq.size() == 0) begin $display("ERROR: debug link: no reply"); errors++; c = 8'h00; end
    else c = dbg_rxq.pop_front();
  endtask
  task automatic dword(logic [31:0] w); for (int b = 0; b < 4; b++) dsend(w[8*b +: 8]); endtask
  task automatic drecv32(output logic [31:0] w);
    logic [7:0] c; for (int b = 0; b < 4; b++) begin drecv(c); w[8*b +: 8] = c; end
  endtask
  task automatic wmem(logic [31:0] a, logic [31:0] v);
    logic [7:0] c;
    dsend(8'h41); dword(a); dword(v); drecv(c);
    if (c !== 8'h90) begin $display("ERROR: WMEM %08h: reply %02h, expected ACK 90", a, c); errors++; end
  endtask
  task automatic rmem_check(logic [31:0] a, logic [31:0] exp);
    logic [31:0] w;
    dsend(8'h40); dword(a); drecv32(w);
    if (w !== exp) begin $display("ERROR: RMEM %08h = %08h, expected %08h", a, w, exp); errors++; end
  endtask

  task automatic three_masters();
    int t0;
    while (dram('h20) != 32'h5741 && cyc < max_cyc) @(posedge clk);
    t0 = cyc;
    $display("[cyc %0d] program loop running: debug unit starts writing DRAM and reading IRAM", cyc);
    for (int i = 0; i < 64; i++) begin
      wmem(32'h8001_1000 + 4 * i, 32'hDB00_0000 | ((i * 32'h0101_0101) & 32'h00FF_FFFF));
      if (i % 8 == 7) rmem_check(32'h8000_0080 + 4 * i, `IRAM[('h80 + 4 * i) / 4]);
    end
    wmem(32'h8001_0024, 32'h0000_0D0E);
    $display("[cyc %0d] debug unit done (%0d cycles of concurrent traffic)", cyc, cyc - t0);
  endtask

  task automatic check_results();
    int fd, n = 0; logic [31:0] g, r;
    fd = $fopen(golden_file, "r");
    if (fd == 0) begin $display("ERROR: cannot open %s", golden_file); errors++; return; end
    while ($fscanf(fd, "%h", g) == 1) begin
      r = dram('h1C00 + 4 * n);
      if (r !== g) begin $display("  [%2d] got %08h expected %08h  MISMATCH", n, r, g); errors++; end
      n++;
    end
    $fclose(fd);
    if (dram('h1BFC) != n) begin
      $display("ERROR: RESULT_N = %0d, golden has %0d", dram('h1BFC), n); errors++;
    end
    $display("checked %0d results against %s: %0s", n, golden_file, errors ? "FAIL" : "all match");
  endtask

  initial begin
    int nrom, ni, nd;
    if (!$value$plusargs("ROM=%s", rom_file))       rom_file = "sw/boot/rom.hex";
    if (!$value$plusargs("IRAM=%s", iram_file))     iram_file = "";
    if (!$value$plusargs("DRAM=%s", dram_file))     dram_file = "";
    if (!$value$plusargs("GOLDEN=%s", golden_file)) golden_file = "";
    if (!$value$plusargs("NAME=%s", name))          name = "?";
    if (!$value$plusargs("MAXCYC=%d", max_cyc))     max_cyc = 3000000;
    #1;
    nrom = load(rom_file, 0, 0);
    ni   = load(iram_file, 1, 0);
    nd   = (dram_file != "") ? load(dram_file, 2, 'h40 / 4) : 0;
    $display("%s: ROM %0d, IRAM %0d, DRAM %0d words", name, nrom, ni, nd);
    if (nrom == 0 || ni == 0) begin errors++; max_cyc = 0; end
    repeat (5) @(posedge clk);
    rst_n = (max_cyc != 0);
    if (rst_n) three_masters();
    while (dram('h00) != 32'hC0DE0001 && (dram('h00) >> 20) != 32'hBAD && cyc < max_cyc) @(posedge clk);
    if (dram('h00) != 32'hC0DE0001) begin
      $display("ERROR: program did not finish: SIG_STATUS %08h, cycle %0d, RESULT_N %0d",
               dram('h00), cyc, dram('h1BFC));
      errors++;
    end else begin
      $display("[cyc %0d] program done", cyc);
      check_results();
    end
    $display("tb_bus %s CLK_GATING=%0d: cycles %0d, errors %0d", name, CLK_GATING, cyc, errors);
    if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
