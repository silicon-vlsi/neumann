`timescale 1ns/1ps
// ============================================================================
//  tb_boot - boot a program into the neumann SoC and check its results.
//
//  +BOOT=sdc : boot pins gpio_i[31:30] = 00. SPI flash model (spiflash.v) on the SDC
//              pins (CS0) holds the image (+firmware=<flash.hex>, made by mkflash.py).
//              The boot ROM copies it into IRAM/DRAM and jumps to it.
//  +BOOT=dbg : boot pins = 10 (debug boot). The ROM clears the mailbox 0x8001_0004 and
//              polls it. The testbench (as the host PC) writes the program over the UART
//              debug link with WMEM (0x41): IRAM image (+IRAM=<words.hex>) to 0x8000_0000,
//              DRAM image (+DRAM=<words.hex>) to 0x8001_0040, reads back the first/last
//              word of each with RMEM (0x40), then writes the entry 0x8000_0080 to the
//              mailbox -> the ROM jumps to the program. The core is NOT halted: the debug
//              unit writes over the bus while the core runs the ROM poll loop.
//  Only the boot ROM is loaded by back-door (+ROM=<rom.hex>); IRAM/DRAM start empty.
//
//  Check: SIG_STATUS (0x8001_0000) = 0xC0DE0001, RESULT_N (0x8001_1BFC) and
//         RESULT[i] (0x8001_1C00 + 4i) equal +GOLDEN=<file> (one hex word per line).
//         SDC boot also needs BOOT_STATUS (0x8001_000C) = 0xB00700AA.
//  Other plusargs: +MAXCYC=<n> (default 10000000), +NAME=<text> for the log line.
// ============================================================================
module tb_boot;
  parameter CLK_GATING = 1;
  localparam DBG_BIT = 16;                     // debug UART: clocks per bit (DBG_CLKS_PER_BIT)

  string boot, rom_file, golden_file, iram_file, dram_file, name;
  int unsigned max_cyc, cyc = 0, errors = 0, boot_done_cyc = 0;
  int nrom;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;                        // 100 MHz
  always @(posedge clk) cyc++;

  logic        dbg_rx = 1;
  logic [1:0]  boot_pins = 2'b00;
  wire         dbg_tx, uart_tx, halted;
  wire  [31:0] gpio_o, gpio_oe;
  wire  [31:0] gpio_i = {boot_pins, 30'b0};
  wire         spi_mosi, spi_sck; wire [3:0] spi_cs;
  wire         sdc_mosi, sdc_sck, sdc_miso; wire [3:0] sdc_cs;

  neumann_soc #(.CLK_GATING(CLK_GATING), .DBG_CLKS_PER_BIT(DBG_BIT)) dut (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0), .fetch_enable_i(1'b1),
    .dbg_rx_i(dbg_rx), .dbg_tx_o(dbg_tx), .dbg_halted_o(halted),
    .uart_rx_i(1'b1), .uart_tx_o(uart_tx),
    .gpio_i(gpio_i), .gpio_o(gpio_o), .gpio_oe_o(gpio_oe),
    .spi_miso_i(1'b0), .spi_mosi_o(spi_mosi), .spi_cs_o(spi_cs), .spi_sck_o(spi_sck),
    .sdc_miso_i(sdc_miso), .sdc_mosi_o(sdc_mosi), .sdc_cs_o(sdc_cs), .sdc_sck_o(sdc_sck));

  // ---------------------------------------------------------------- SPI flash on the SDC port
  wire flash_io0 = sdc_mosi;
  wire flash_io1, flash_io2, flash_io3;
  spiflash u_flash (.csb(sdc_cs[0]), .clk(sdc_sck),
                    .io0(flash_io0), .io1(flash_io1), .io2(flash_io2), .io3(flash_io3));
  assign sdc_miso = (flash_io1 === 1'b1);

  // ---------------------------------------------------------------- back-door
  `define ROM  dut.u_uncore.bootrom.bootrom.memory.ROM
  `define DRAM dut.u_dram.memory.ram.RAM
  function automatic logic [31:0] dram(int byte_off); return `DRAM[byte_off / 4]; endfunction

  logic [31:0] img [0:4095];
  function automatic int read_words(string f);   // one 32-bit hex word per line
    int n = 0, fd; logic [31:0] w;
    fd = $fopen(f, "r");
    if (fd == 0) begin $display("ERROR: cannot open %s", f); errors++; return 0; end
    while (n < 4096 && $fscanf(fd, "%h", w) == 1) begin img[n] = w; n++; end
    $fclose(fd);
    return n;
  endfunction

  // ---------------------------------------------------------------- UART debug link (host side)
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
    if (w !== exp) begin $display("ERROR: RMEM %08h = %08h, wrote %08h", a, w, exp); errors++; end
  endtask

  task automatic load_image(string f, logic [31:0] base, string what);
    int n;
    logic [31:0] first, last;
    n = read_words(f);
    first = img[0];
    last  = img[(n > 0) ? n - 1 : 0];
    $display("[cyc %0d] debug link: WMEM %0d words of %s to %08h", cyc, n, what, base);
    for (int k = 0; k < n; k++) begin
      wmem(base + 4 * k, img[k]);
      if (k % 512 == 511) $display("[cyc %0d]   %0d / %0d words", cyc, k + 1, n);
    end
    if (n > 0) begin rmem_check(base, first); rmem_check(base + 4 * (n - 1), last); end
  endtask

  task automatic dbg_boot();
    repeat (300) @(posedge clk);                // ROM has cleared the mailbox by now
    if (dram('h04) != 0) begin $display("ERROR: mailbox not cleared by the ROM"); errors++; end
    load_image(iram_file, 32'h8000_0000, "IRAM");
    if (dram_file != "") load_image(dram_file, 32'h8001_0040, "DRAM");
    wmem(32'h8001_0004, 32'h8000_0080);         // entry -> mailbox: ROM jumps there
    boot_done_cyc = cyc;
    $display("[cyc %0d] debug boot: entry written to the mailbox", cyc);
  endtask

  // ---------------------------------------------------------------- check
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

  // progress line every 500 k cycles (long runs: debug-UART boot of rtos ~4 M cycles)
  always @(posedge clk) if (cyc % 500000 == 0 && cyc > 0)
    $display("[cyc %0d] running... SIG_STATUS %08h BOOT_STATUS %08h", cyc, dram('h00), dram('h0C));

  logic [31:0] boot_status_q = 0;
  always @(posedge clk) if (rst_n && dram('h0C) != boot_status_q) begin
    boot_status_q <= dram('h0C);
    $display("[cyc %0d] BOOT_STATUS = %08h", cyc, dram('h0C));
    if (dram('h0C) == 32'hB00700AA) boot_done_cyc = cyc;
  end

  initial begin
    if (!$value$plusargs("BOOT=%s", boot)) boot = "sdc";
    if (!$value$plusargs("ROM=%s", rom_file)) rom_file = "sw/boot/rom.hex";
    if (!$value$plusargs("GOLDEN=%s", golden_file)) golden_file = "";
    if (!$value$plusargs("IRAM=%s", iram_file)) iram_file = "";
    if (!$value$plusargs("DRAM=%s", dram_file)) dram_file = "";
    if (!$value$plusargs("NAME=%s", name)) name = "?";
    if (!$value$plusargs("MAXCYC=%d", max_cyc)) max_cyc = 10000000;
    boot_pins = (boot == "dbg") ? 2'b10 : 2'b00;
    #1;
    // (no initialiser on a declaration here: in an initial block it would run at time 0,
    //  before the plusargs above are read)
    nrom = read_words(rom_file);
    for (int k = 0; k < nrom && k < 1024; k++) `ROM[k] = img[k];
    $display("boot ROM: %0d words from %s; BOOT=%s program=%s", nrom, rom_file, boot, name);
    if (nrom == 0) begin $display("ERROR: empty boot ROM image"); $display("RESULT: FAIL"); $finish; end
    repeat (5) @(posedge clk);
    rst_n = 1;
    if (boot == "dbg") dbg_boot();
    while (dram('h00) != 32'hC0DE0001 && (dram('h00) >> 20) != 32'hBAD && cyc < max_cyc) @(posedge clk);
    if (dram('h00) != 32'hC0DE0001) begin
      $display("ERROR: program did not finish: SIG_STATUS %08h, BOOT_STATUS %08h, cycle %0d",
               dram('h00), dram('h0C), cyc);
      errors++;
    end else begin
      $display("[cyc %0d] program done (%0d cycles after boot)", cyc, cyc - boot_done_cyc);
      if (boot == "sdc" && dram('h0C) != 32'hB00700AA) begin
        $display("ERROR: BOOT_STATUS %08h, expected B00700AA", dram('h0C)); errors++;
      end
      check_results();
    end
    $display("tb_boot %s BOOT=%s CLK_GATING=%0d: cycles %0d, errors %0d", name, boot, CLK_GATING, cyc, errors);
    if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
