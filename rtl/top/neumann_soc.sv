// =============================================================================
// neumann_soc.sv
// neumann RV32IC core + ebu3 (3-master EBU) on the CORE-V-Wally uncore (AHB-Lite / APB).
//
// Part of neumann_soc. Diagram: doc/block_diagram.drawio,
// memory map: doc/MEMORY_MAP.md, config: config/config.vh.
//
//   rv32i_core --instr--> obi2ahb_i --IFU  m0 --+
//              --data---> obi2ahb_d --LSU  m1 --+--> ebu3 -----> uncore (decoder,
//   uart_debug_unit                             |  DBG>LSU>IFU    IRAM, boot ROM,
//              --mem_*--> obi2ahb_d --DBG  m2 --+                 APB: CLINT PLIC
//              --debug_*-> core debug port                        UART SPI GPIO)
//   irq_enc <-- MTimerInt / MSwInt / MExtInt (from uncore)
//   DRAM (ram_ahb) on the uncore EXT slot (HSELEXT)
//
// Memory map (config.vh):
//   0x0000_1000  Boot ROM 4 KB      (boot_addr, first fetch 0x0000_1080)
//   0x0200_0000  CLINT              0x0C00_0000 PLIC
//   0x1000_0000  UART (16550)       0x1004_0000 SPI     0x1006_0000 GPIO
//   0x0001_3000  SDC (2nd SPI master)
//   0x8000_0000  IRAM 16 KB (64 KB window)
//   0x8001_0000  DRAM  8 KB (64 KB window, EXT slot)
//
// Clock / reset: one clock. rst_ni is synchronised here (rst_sync) and drives
// the core (async reset), the debug unit and Wally (HRESETn).
// =============================================================================
module neumann_soc import cvw::*; #(
    parameter        CLK_GATING       = 1,            // core clock gates (0 = none, FPGA)
    parameter        DBG_CLKS_PER_BIT = 868,          // UART debug link: clk / baud
    parameter [31:0] BOOT_ADDR        = 32'h0000_1000,
    parameter [63:0] IRAM_PHYS_RANGE  = 64'h0000_3FFF, // 16 KB
    parameter [63:0] DRAM_PHYS_RANGE  = 64'h0000_1FFF  //  8 KB
) (
    input         clk_i,
    input         rst_ni,
    input         test_en_i,       // DFT: clock-gate enable / reset bypass
    input         fetch_enable_i,  // 1: core starts fetching after reset

    // UART debug link (our debug unit)
    input         dbg_rx_i,
    output        dbg_tx_o,
    output        dbg_halted_o,    // core halted by debug (LED)

    // application UART (Wally 16550)
    input         uart_rx_i,
    output        uart_tx_o,

    // GPIO
    input  [31:0] gpio_i,
    output [31:0] gpio_o,
    output [31:0] gpio_oe_o,

    // SPI master (boot flash)
    input         spi_miso_i,
    output        spi_mosi_o,
    output [3:0]  spi_cs_o,
    output        spi_sck_o,
    // SDC = Wally's 2nd SPI master (SD card in SPI mode, or a 2nd SPI bus)
    input         sdc_miso_i,
    output        sdc_mosi_o,
    output [3:0]  sdc_cs_o,
    output        sdc_sck_o
);
  `include "config.vh"
  `include "parameter-defs.vh"

  localparam int PA = P.PA_BITS;

  // ---------------------------------------------------------------- reset
  wire rst_n;
  rst_sync u_rst (.clk_i(clk_i), .rst_ni(rst_ni), .test_mode_i(test_en_i), .rst_no(rst_n));

  // ---------------------------------------------------------------- core
  wire        i_req, i_gnt, i_rvalid, i_err;
  wire [31:0] i_addr, i_rdata;
  wire        c_req, c_gnt, c_rvalid, c_we, c_err;
  wire [3:0]  c_be;
  wire [31:0] c_addr, c_wdata, c_rdata;
  wire        irq, irq_ack;
  wire [4:0]  irq_id, irq_ack_id;
  wire        dbg_req, dbg_gnt, dbg_rvalid, dbg_we;
  wire [14:0] dbg_addr;
  wire [31:0] dbg_wdata, dbg_rdata;
  wire        core_busy;

  rv32i_core #(.CLK_GATING(CLK_GATING)) u_core (
    .clk_i(clk_i), .rst_ni(rst_n), .clock_en_i(1'b1), .test_en_i(test_en_i),
    .core_id_i(4'd0), .cluster_id_i(6'd0), .boot_addr_i(BOOT_ADDR),
    .instr_req_o(i_req), .instr_gnt_i(i_gnt), .instr_rvalid_i(i_rvalid),
    .instr_addr_o(i_addr), .instr_rdata_i(i_rdata),
    .data_req_o(c_req), .data_gnt_i(c_gnt), .data_rvalid_i(c_rvalid),
    .data_we_o(c_we), .data_be_o(c_be), .data_wdata_o(c_wdata),
    .data_addr_o(c_addr), .data_rdata_i(c_rdata), .data_err_i(c_err),
    .irq_i(irq), .irq_id_i(irq_id), .irq_ack_o(irq_ack), .irq_id_o(irq_ack_id),
    .debug_req_i(dbg_req), .debug_gnt_o(dbg_gnt), .debug_rvalid_o(dbg_rvalid),
    .debug_addr_i(dbg_addr), .debug_we_i(dbg_we), .debug_wdata_i(dbg_wdata),
    .debug_rdata_o(dbg_rdata), .debug_halted_o(dbg_halted_o),
    .debug_halt_i(1'b0), .debug_resume_i(1'b0),
    .fetch_enable_i(fetch_enable_i), .core_busy_o(core_busy));

  // ---------------------------------------------------------------- UART debug unit
  wire        um_req, um_gnt, um_rvalid, um_we;
  wire [3:0]  um_be;
  wire [31:0] um_addr, um_wdata, um_rdata;

  uart_debug_unit #(.CLKS_PER_BIT(DBG_CLKS_PER_BIT)) u_dbg (
    .clk(clk_i), .rst_n(rst_n), .rx_i(dbg_rx_i), .tx_o(dbg_tx_o),
    .dbg_req_o(dbg_req), .dbg_gnt_i(dbg_gnt), .dbg_rvalid_i(dbg_rvalid),
    .dbg_addr_o(dbg_addr), .dbg_we_o(dbg_we), .dbg_wdata_o(dbg_wdata), .dbg_rdata_i(dbg_rdata),
    .mem_req_o(um_req), .mem_gnt_i(um_gnt), .mem_rvalid_i(um_rvalid),
    .mem_we_o(um_we), .mem_be_o(um_be), .mem_addr_o(um_addr), .mem_wdata_o(um_wdata),
    .mem_rdata_i(um_rdata));

  // ---------------------------------------------------------------- OBI -> AHB bridges
  logic [1:0]    IFUHTRANS, LSUHTRANS, DBGHTRANS, HTRANS;
  logic [2:0]    IFUHSIZE, IFUHBURST, LSUHSIZE, LSUHBURST, DBGHSIZE, DBGHBURST, HSIZE, HBURST;
  logic [PA-1:0] IFUHADDR, LSUHADDR, DBGHADDR, HADDR;
  logic          IFUHGRANT, LSUHGRANT, DBGHGRANT, LSUHWRITE, DBGHWRITE;
  logic          HCLK, HRESETn, HREADY, HRESP, HWRITE, HMASTLOCK;
  logic [31:0]   LSUHWDATA, DBGHWDATA, HWDATA, HRDATA;
  logic [3:0]    LSUHWSTRB, DBGHWSTRB, HWSTRB, HPROT;
  logic [1:0]    HMASTER;
  wire           um_err;   // debug unit has no error input

  assign HCLK    = clk_i;
  assign HRESETn = rst_n;

  // core instruction port: master 0 (lowest priority)
  obi2ahb_i #(.PA_BITS(PA)) u_bi (.HCLK(clk_i), .HRESETn(rst_n),
    .instr_req_i(i_req), .instr_addr_i(i_addr), .instr_gnt_o(i_gnt),
    .instr_rvalid_o(i_rvalid), .instr_rdata_o(i_rdata), .instr_err_o(i_err),
    .HTRANS(IFUHTRANS), .HSIZE(IFUHSIZE), .HBURST(IFUHBURST), .HADDR(IFUHADDR),
    .HREADY(HREADY), .HRDATA(HRDATA), .HRESP(HRESP), .hold_i(~IFUHGRANT));

  // core data port: master 1
  obi2ahb_d #(.PA_BITS(PA)) u_bd (.HCLK(clk_i), .HRESETn(rst_n),
    .data_req_i(c_req), .data_addr_i(c_addr), .data_we_i(c_we), .data_be_i(c_be),
    .data_wdata_i(c_wdata), .data_gnt_o(c_gnt), .data_rvalid_o(c_rvalid),
    .data_rdata_o(c_rdata), .data_err_o(c_err),
    .HTRANS(LSUHTRANS), .HWRITE(LSUHWRITE), .HSIZE(LSUHSIZE), .HBURST(LSUHBURST),
    .HADDR(LSUHADDR), .HWDATA(LSUHWDATA), .HWSTRB(LSUHWSTRB),
    .HREADY(HREADY), .HRDATA(HRDATA), .HRESP(HRESP), .hold_i(~LSUHGRANT));

  // UART debug unit memory port: master 2 (highest priority)
  obi2ahb_d #(.PA_BITS(PA)) u_bg (.HCLK(clk_i), .HRESETn(rst_n),
    .data_req_i(um_req), .data_addr_i(um_addr), .data_we_i(um_we), .data_be_i(um_be),
    .data_wdata_i(um_wdata), .data_gnt_o(um_gnt), .data_rvalid_o(um_rvalid),
    .data_rdata_o(um_rdata), .data_err_o(um_err),
    .HTRANS(DBGHTRANS), .HWRITE(DBGHWRITE), .HSIZE(DBGHSIZE), .HBURST(DBGHBURST),
    .HADDR(DBGHADDR), .HWDATA(DBGHWDATA), .HWSTRB(DBGHWSTRB),
    .HREADY(HREADY), .HRDATA(HRDATA), .HRESP(HRESP), .hold_i(~DBGHGRANT));

  // ---------------------------------------------------------------- EBU (3 -> 1, DBG > LSU > IFU)
  ebu3 #(.PA_BITS(PA)) u_ebu (.HCLK, .HRESETn,
    .IFUHBUSREQ(i_req),  .IFUHGRANT, .IFUHTRANS, .IFUHSIZE, .IFUHBURST, .IFUHADDR,
    .LSUHBUSREQ(c_req),  .LSUHGRANT, .LSUHTRANS, .LSUHWRITE, .LSUHSIZE, .LSUHBURST, .LSUHADDR,
    .LSUHWDATA, .LSUHWSTRB,
    .DBGHBUSREQ(um_req), .DBGHGRANT, .DBGHTRANS, .DBGHWRITE, .DBGHSIZE, .DBGHBURST, .DBGHADDR,
    .DBGHWDATA, .DBGHWSTRB,
    .HREADY, .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK,
    .HMASTER);

  // ---------------------------------------------------------------- uncore
  logic        HSELEXT, HREADYEXT, HRESPEXT;
  logic [31:0] HRDATAEXT;
  logic        MTimerInt, MSwInt, MExtInt, SExtInt;
  logic [63:0] MTIME_CLINT;
  logic [3:0]  PWMGPIO;

  uncore #(.P(P), .RAM_PHYS_RANGE(IRAM_PHYS_RANGE)) u_uncore (
    .HCLK, .HRESETn, .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK,
    .HRDATAEXT, .HREADYEXT, .HRESPEXT, .HRDATA, .HREADY, .HRESP, .HSELEXT,
    .MTimerInt, .MSwInt, .MExtInt, .SExtInt, .MTIME_CLINT,
    .GPIOIN(gpio_i), .GPIOOUT(gpio_o), .GPIOEN(gpio_oe_o),
    .UARTSin(uart_rx_i), .UARTSout(uart_tx_o),
    .SPIIn(spi_miso_i), .SPIOut(spi_mosi_o), .SPICS(spi_cs_o), .SPICLK(spi_sck_o),
    .SDCIn(sdc_miso_i), .SDCCmd(sdc_mosi_o), .SDCCS(sdc_cs_o), .SDCCLK(sdc_sck_o), .PWMGPIO);

  // ---------------------------------------------------------------- DRAM on the EXT slot
  ram_ahb #(.P(P), .RANGE(DRAM_PHYS_RANGE), .PRELOAD(0)) u_dram (
    .HCLK, .HRESETn, .HSELRam(HSELEXT), .HADDR, .HWRITE, .HREADY,
    .HTRANS, .HWDATA, .HWSTRB, .HREADRam(HRDATAEXT), .HRESPRam(HRESPEXT), .HREADYRam(HREADYEXT));

  // ---------------------------------------------------------------- interrupts
  irq_enc u_irq (.mei_i(MExtInt), .msi_i(MSwInt), .mti_i(MTimerInt), .irq_o(irq), .irq_id_o(irq_id));

endmodule
