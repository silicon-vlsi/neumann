`timescale 1ns/1ps
// ============================================================================
//  tb_periph - interrupt and peripheral tests on the neumann SoC.
//
//  Back-door preload (+IRAM=<hex> from 0x8000_0000, +DRAM=<hex> from 0x8001_0040,
//  +ROM=<rom.hex>), boot pins gpio_i[31:30] = 01: the ROM jumps to 0x8000_0080.
//  Connections:
//    uart_rx_i   = uart_tx_o              application UART loopback
//    SPI CS0     -> spi_mem               256-byte SPI memory (write 0x02, read 0x03)
//    gpio_i = gpio_o where gpio_oe_o = 1  GPIO loopback, all 32 pins (else 0, boot pins 01)
//  Check: SIG_STATUS (0x8001_0000) = 0xC0DE0001, RESULT_N (0x8001_1BFC) and
//         RESULT[i] (0x8001_1C00 + 4i) equal +GOLDEN=<file> (one hex word per line).
//  Plusargs: +MAXCYC=<n> (default 3000000), +NAME=<text>.
// ============================================================================
module tb_periph;
  parameter CLK_GATING = 1;

  string rom_file, iram_file, dram_file, golden_file, name;
  int unsigned max_cyc, cyc = 0, errors = 0;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;                        // 100 MHz
  always @(posedge clk) cyc++;

  wire        dbg_tx, uart_tx, halted;
  wire [31:0] gpio_o, gpio_oe;
  // GPIO loopback on all 32 pins: a pin reads back its own output while gpio_oe_o = 1;
  // otherwise it reads the board default (boot pins 31:30 = 01 = direct boot, others 0)
  wire [31:0] gpio_i = (gpio_o & gpio_oe) | (~gpio_oe & 32'h4000_0000);
  wire        spi_mosi, spi_sck, spi_miso, sdc_mosi, sdc_sck;
  wire [3:0]  spi_cs, sdc_cs;

  neumann_soc #(.CLK_GATING(CLK_GATING)) dut (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0), .fetch_enable_i(1'b1),
    .dbg_rx_i(1'b1), .dbg_tx_o(dbg_tx), .dbg_halted_o(halted),
    .uart_rx_i(uart_tx), .uart_tx_o(uart_tx),
    .gpio_i(gpio_i), .gpio_o(gpio_o), .gpio_oe_o(gpio_oe),
    .spi_miso_i(spi_miso), .spi_mosi_o(spi_mosi), .spi_cs_o(spi_cs), .spi_sck_o(spi_sck),
    .sdc_miso_i(1'b0), .sdc_mosi_o(sdc_mosi), .sdc_cs_o(sdc_cs), .sdc_sck_o(sdc_sck));

  spi_mem u_spi_mem (.cs_n(spi_cs[0]), .sck(spi_sck), .mosi(spi_mosi), .miso(spi_miso));

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
    while (dram('h00) != 32'hC0DE0001 && (dram('h00) >> 20) != 32'hBAD && cyc < max_cyc) @(posedge clk);
    if (dram('h00) != 32'hC0DE0001) begin
      $display("ERROR: program did not finish: SIG_STATUS %08h, cycle %0d, RESULT_N %0d",
               dram('h00), cyc, dram('h1BFC));
      errors++;
    end else begin
      $display("[cyc %0d] program done; SPI memory model: %0d bytes written, %0d bytes read",
               cyc, u_spi_mem.n_wr, u_spi_mem.n_rd);
      check_results();
    end
    $display("tb_periph %s CLK_GATING=%0d: cycles %0d, errors %0d", name, CLK_GATING, cyc, errors);
    if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
