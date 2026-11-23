`timescale 1ns/1ps
// ============================================================================
//  tb_sdc_boot - program the neumann SoC through the SDC port and check the result.
//
//  SPI flash model (flash/spiflash.v, PicoSoC) on the SDC pins, CS0:
//      sdc_sck_o -> clk   sdc_mosi_o -> io0   io1 -> sdc_miso_i   sdc_cs_o[0] -> csb
//  Boot pins gpio_i[31:30] = 00 -> the boot ROM copies the image from the flash
//  into IRAM/DRAM and jumps to it (see sw/boot/rom.S).
//  Only the boot ROM is loaded by back-door; IRAM/DRAM start empty.
//
//  Plusargs:
//    +ROM=<rom.hex>        boot ROM image (default sw/boot/rom.hex)
//    +firmware=<flash.hex> flash content, read by spiflash.v (one byte per line)
//    +GOLDEN=<file>        expected results, one hex word per line (EXPECT=pass)
//    +EXPECT=pass|e1|e2|e3 pass: program must run and match golden
//                          e1/e2/e3: boot ROM must report bad magic / length /
//                          checksum and fall back to debug boot (stay in ROM)
//    +MAXCYC=<n>           timeout in clock cycles (default 3000000)
//  Result words: DRAM 0x8001_1000 + 4 i,  count at 0x8001_0FFC,
//                status 0x8001_0000 (0xC0DE0001 = program finished),
//                boot status 0x8001_000C (written by the boot ROM).
// ============================================================================
module tb_sdc_boot;
  parameter CLK_GATING = 1;

  string rom_file, golden_file, expect_s;
  int unsigned max_cyc, cyc = 0, errors = 0;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;                       // 100 MHz
  always @(posedge clk) cyc++;

  wire         dbg_tx, uart_tx, halted;
  wire  [31:0] gpio_o, gpio_oe;
  wire  [31:0] gpio_i = 32'h0000_0000;        // boot pins [31:30] = 00 -> SDC flash boot
  wire         spi_mosi, spi_sck; wire [3:0] spi_cs;
  wire         sdc_mosi, sdc_sck, sdc_miso; wire [3:0] sdc_cs;

  neumann_soc #(.CLK_GATING(CLK_GATING)) dut (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0), .fetch_enable_i(1'b1),
    .dbg_rx_i(1'b1), .dbg_tx_o(dbg_tx), .dbg_halted_o(halted),
    .uart_rx_i(1'b1), .uart_tx_o(uart_tx),
    .gpio_i(gpio_i), .gpio_o(gpio_o), .gpio_oe_o(gpio_oe),
    .spi_miso_i(1'b0), .spi_mosi_o(spi_mosi), .spi_cs_o(spi_cs), .spi_sck_o(spi_sck),
    .sdc_miso_i(sdc_miso), .sdc_mosi_o(sdc_mosi), .sdc_cs_o(sdc_cs), .sdc_sck_o(sdc_sck));

  // ---------------------------------------------------------------- SPI flash on the SDC port
  wire flash_io0 = sdc_mosi;
  wire flash_io1;
  wire flash_io2, flash_io3;
  spiflash u_flash (.csb(sdc_cs[0]), .clk(sdc_sck),
                    .io0(flash_io0), .io1(flash_io1), .io2(flash_io2), .io3(flash_io3));
  assign sdc_miso = (flash_io1 === 1'b1);     // flash io1 is 'z' when not driving -> 0

  // ---------------------------------------------------------------- back-door memories
  `define ROM  dut.u_uncore.bootrom.bootrom.memory.ROM
  `define DRAM dut.u_dram.memory.ram.RAM
  function automatic logic [31:0] dram(int byte_off); return `DRAM[byte_off / 4]; endfunction

  task automatic load_rom(string f);
    int n = 0, fd; logic [31:0] w;
    fd = $fopen(f, "r");
    if (fd == 0) begin $display("ERROR: cannot open %s", f); errors++; return; end
    while (n < 1024 && $fscanf(fd, "%h", w) == 1) begin `ROM[n] = w; n++; end
    $fclose(fd);
    $display("boot ROM: %0d words from %s", n, f);
  endtask

  // ---------------------------------------------------------------- SDC bus monitor
  int unsigned cs_frames = 0, sck_edges = 0;
  logic cs_q = 1, sck_q = 0;
  always @(posedge clk) begin
    cs_q <= sdc_cs[0]; sck_q <= sdc_sck;
    if (rst_n && cs_q && !sdc_cs[0]) cs_frames++;
    if (!sck_q && sdc_sck && !sdc_cs[0]) sck_edges++;
  end

  logic [31:0] boot_status_q = 0;
  always @(posedge clk) if (rst_n && dram('h0C) != boot_status_q) begin
    boot_status_q <= dram('h0C);
    $display("[cyc %0d] BOOT_STATUS = %08h", cyc, dram('h0C));
  end

  // ---------------------------------------------------------------- checks
  task automatic check_pass();
    int fd, n = 0; logic [31:0] g, r;
    while (dram('h00) != 32'hC0DE0001 && cyc < max_cyc) begin
      if ((dram('h00) >> 20) == 32'hBAD) begin
        $display("ERROR: program trapped, SIG_STATUS %08h", dram('h00)); errors++; return;
      end
      @(posedge clk);
    end
    if (cyc >= max_cyc) begin
      $display("ERROR: timeout, BOOT_STATUS %08h SIG_STATUS %08h", dram('h0C), dram('h00));
      errors++; return;
    end
    $display("[cyc %0d] program done, SIG_STATUS %08h", cyc, dram('h00));
    if (dram('h0C) != 32'hB00700AA) begin
      $display("ERROR: BOOT_STATUS %08h, expected B00700AA", dram('h0C)); errors++;
    end
    fd = $fopen(golden_file, "r");
    if (fd == 0) begin $display("ERROR: cannot open %s", golden_file); errors++; return; end
    while ($fscanf(fd, "%h", g) == 1) begin
      r = dram('h1000 + 4 * n);
      if (r !== g) begin
        $display("  [%2d] got %08h expected %08h  MISMATCH", n, r, g); errors++;
      end else
        $display("  [%2d] %08h ok", n, r);
      n++;
    end
    $fclose(fd);
    if (dram('h0FFC) != n) begin
      $display("ERROR: result count %0d, golden has %0d", dram('h0FFC), n); errors++;
    end
    $display("checked %0d results against %s", n, golden_file);
  endtask

  task automatic check_fail(logic [31:0] code);
    int unsigned in_rom = 0;
    while (dram('h0C) != code && cyc < max_cyc) begin
      if (dram('h0C) == 32'hB00700AA || dram('h00) == 32'hC0DE0001) begin
        $display("ERROR: bad image was accepted (BOOT_STATUS %08h)", dram('h0C)); errors++; return;
      end
      @(posedge clk);
    end
    if (cyc >= max_cyc) begin
      $display("ERROR: timeout waiting for BOOT_STATUS %08h (now %08h)", code, dram('h0C));
      errors++; return;
    end
    // fallback = debug boot: the core must stay in the ROM mailbox loop
    repeat (2000) begin
      @(posedge clk);
      if (dut.i_req && dut.i_addr[31:12] != 20'h00001) begin
        $display("ERROR: fetch outside ROM at %08h after a failed boot", dut.i_addr); errors++; return;
      end
      in_rom++;
    end
    if (sdc_cs[0] !== 1'b1) begin $display("ERROR: SDC CS0 still asserted"); errors++; end
    $display("boot ROM rejected the image (BOOT_STATUS %08h), waiting in debug boot: ok", code);
  endtask

  initial begin
    if (!$value$plusargs("ROM=%s", rom_file)) rom_file = "sw/boot/rom.hex";
    if (!$value$plusargs("GOLDEN=%s", golden_file)) golden_file = "TEST/Test_via_sdc/golden/gcd.golden";
    if (!$value$plusargs("EXPECT=%s", expect_s)) expect_s = "pass";
    if (!$value$plusargs("MAXCYC=%d", max_cyc)) max_cyc = 3000000;
    #1;
    load_rom(rom_file);
    repeat (5) @(posedge clk);
    rst_n = 1;
    case (expect_s)
      "pass": check_pass();
      "e1":   check_fail(32'hB00700E1);
      "e2":   check_fail(32'hB00700E2);
      "e3":   check_fail(32'hB00700E3);
      default: begin $display("ERROR: unknown +EXPECT=%s", expect_s); errors++; end
    endcase
    $display("tb_sdc_boot EXPECT=%s CLK_GATING=%0d: cycles %0d, SDC CS frames %0d, SCK edges %0d (%0d bytes), errors %0d",
             expect_s, CLK_GATING, cyc, cs_frames, sck_edges, sck_edges / 8, errors);
    if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
