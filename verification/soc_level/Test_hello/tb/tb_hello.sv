// tb_hello.sv - the smallest neumann testbench. Four steps, same as every other suite:
//   1. put the program in the chip   (write hello_iram.hex straight into IRAM, "back-door")
//   2. let it run                    (boot pins 01 = direct boot -> ROM jumps to 0x8000_0080)
//   3. read the answer from memory   (DRAM 0x8001_1000, after "done" 0xC0DE0001 appears)
//   4. compare with the answer key   (golden/hello.golden) -> RESULT: PASS / FAIL
module tb_hello;
  parameter CLK_GATING = 1;

  // ---- clock 100 MHz and reset -------------------------------------------------------
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;                       // 10 ns period
  int cyc = 0;
  always @(posedge clk) cyc++;

  // ---- the chip ------------------------------------------------------------------------
  wire        dbg_tx, uart_tx, halted, spi_mosi, spi_sck, sdc_mosi, sdc_sck;
  wire [31:0] gpio_o, gpio_oe;
  wire [3:0]  spi_cs, sdc_cs;
  wire [31:0] gpio_i = {2'b01, 30'b0};        // boot pins [31:30] = 01 -> direct boot

  neumann_soc #(.CLK_GATING(CLK_GATING)) dut (
    .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0), .fetch_enable_i(1'b1),
    .dbg_rx_i(1'b1), .dbg_tx_o(dbg_tx), .dbg_halted_o(halted),
    .uart_rx_i(1'b1), .uart_tx_o(uart_tx),
    .gpio_i(gpio_i), .gpio_o(gpio_o), .gpio_oe_o(gpio_oe),
    .spi_miso_i(1'b0), .spi_mosi_o(spi_mosi), .spi_cs_o(spi_cs), .spi_sck_o(spi_sck),
    .sdc_miso_i(1'b0), .sdc_mosi_o(sdc_mosi), .sdc_cs_o(sdc_cs), .sdc_sck_o(sdc_sck));

  // ---- where the memories are inside the chip (hierarchical paths) ---------------------
  `define ROM  dut.u_uncore.bootrom.bootrom.memory.ROM      // boot ROM, 0x0000_1000
  `define IRAM dut.u_uncore.ram.ram.memory.ram.RAM          // IRAM,     0x8000_0000
  `define DRAM dut.u_dram.memory.ram.RAM                    // DRAM,     0x8001_0000
  function automatic logic [31:0] dram(int byte_off); return `DRAM[byte_off / 4]; endfunction

  initial begin
    string rom_file, iram_file, golden_file;
    logic [31:0] answer, expected;
    int fd;
    if (!$value$plusargs("ROM=%s", rom_file))       rom_file    = "sw/boot/rom.hex";
    if (!$value$plusargs("IRAM=%s", iram_file))     iram_file   = "verification/soc_level/Test_hello/prebuilt/hello_iram.hex";
    if (!$value$plusargs("GOLDEN=%s", golden_file)) golden_file = "verification/soc_level/Test_hello/golden/hello.golden";

    // STEP 1: put the boot ROM and our program into the chip's memories
    #1;
    $readmemh(rom_file,  `ROM);
    $readmemh(iram_file, `IRAM);
    $display("step 1: loaded %s into IRAM", iram_file);

    // STEP 2: release reset and let the chip run until it writes "done"
    repeat (5) @(posedge clk);
    rst_n = 1;
    while (dram('h0000) != 32'hC0DE0001 && cyc < 10000) @(posedge clk);
    if (dram('h0000) != 32'hC0DE0001) begin
      $display("step 2: program did not finish (SIG_STATUS = %08h)", dram('h0000));
      $display("RESULT: FAIL");
      $finish;
    end
    $display("step 2: program finished at cycle %0d (SIG_STATUS = %08h)", cyc, dram('h0000));

    // STEP 3: read the answer the program wrote
    answer = dram('h1000);                     // DRAM 0x8001_1000
    $display("step 3: chip answer   = %08h (%0d)", answer, answer);

    // STEP 4: compare with the answer key made by Python
    fd = $fopen(golden_file, "r");
    if (fd == 0 || $fscanf(fd, "%h", expected) != 1) begin
      $display("step 4: cannot read %s", golden_file); $display("RESULT: FAIL"); $finish;
    end
    $fclose(fd);
    $display("step 4: golden answer = %08h (%0d)", expected, expected);
    if (answer === expected) $display("RESULT: PASS");
    else                     $display("RESULT: FAIL");
    $finish;
  end
endmodule
