# neumann_soc: Synthesis / PD handover

Microcontroller: RV32IC + Zicsr core, AHB-Lite/APB uncore. Target: GF 28nm, tape-out Jan 2027.
Owner: Pratyush Kumar Sahu. Guide: Saroj Rout Sir.

## 1. What to synthesise

| Item | Value |
|---|---|
| Top module | `neumann_soc` (`rtl/top/neumann_soc.sv`) |
| File list | `handover/neumann_soc_synth.f` (paths relative to `neumann_soc/`) |
| Defines (tape-out) | `+define+NEUMANN_GF28_SRAM +define+NEUMANN_GF28_ICG` |
| Parameters | keep defaults: `CLK_GATING=1`, `DBG_CLKS_PER_BIT=868`, `BOOT_ADDR=0x1000`, IRAM 16 KB, DRAM 8 KB |
| Clock | 1 clock `clk_i`; verified at 100 MHz (10 ns) |
| Reset | `rst_ni` active-low async, synchronised inside (`rtl/sys/rst_sync.v`) |
| Language | SystemVerilog-2012 + Verilog-2001; package `rtl/peripherals/src/cvw.sv` must be read first (already first in the list) |

`neumann_soc_synth.f` is the verified `neumann_soc.f` with **3 files swapped** (all in `handover/rtl_synth/`):

| RTL file (simulation) | Synthesis file | Why |
|---|---|---|
| `rtl/peripherals/src/generic/mem/rom1p1r.sv` | `rom1p1r_bootrom.sv` | **RTL ROM is empty.** The testbenches back-door load `sw/boot/rom.hex`. Without this swap, silicon gets an all-zero ROM and **will not boot.** |
| `rtl/peripherals/src/generic/mem/ram1p1rwbe.sv` | `ram1p1rwbe_gf28.sv` | IRAM/DRAM become SRAM macros. Without them you get 24 KB of flops. |
| `rtl/core/cluster_clock_gating.sv` | `cluster_clock_gating_gf28.sv` | Library ICG cell in place of the behavioural latch + AND |

Without the defines, the 3 files fall back to behaviour identical to the RTL, so the same list also simulates.

## 2. Items the PD team must fill in (marked `TODO(PD)` / `<...>`)

1. **ICG cell**: in `cluster_clock_gating_gf28.sv`, replace `GF28_ICG_CELL` and its pins. Pin mapping: CK=`clk_i`, E=`en_i`, SE=`test_en_i`, GCK=`clk_o`. This is a latch-based positive-edge ICG with a test enable. There are 32 instances: 1 core clock gate and 31 register-file gates.
2. **SRAM macros**: in `ram1p1rwbe_gf28.sv`, replace `GF28_SRAM_4096X32` and `GF28_SRAM_2048X32` and their pin names. Invert the polarity if the compiler uses active-low enables.

   | Memory | Instance path | Size | Address |
   |---|---|---|---|
   | IRAM | `u_uncore.ram.ram.memory` | 4096 × 32, byte write enable (4 bytes) | 0x8000_0000 |
   | DRAM | `u_dram.memory` | 2048 × 32, byte write enable | 0x8001_0000 |

   Both memories need:
   - single port, synchronous;
   - read data valid 1 cycle after the address, and it must **hold** until the next read;
   - no reset and no init contents.

   Any read-during-write mode is OK, because the bus stalls a read that follows a write. `ce` is tied to 1 (always enabled). A 2048 × 32 macro used twice (banked on `addr[11]`) is fine for the IRAM.
3. **Boot ROM**: synthesised as standard cells from a case table (4 KB address space, 161 words used, 129 non-zero). No ROM macro is needed. If `sw/boot/rom.hex` ever changes, run `python handover/gen_bootrom.py` and re-synthesise.
4. **SDC**: `handover/constraints/neumann_soc_gf28.sdc`. Fill in the uncertainty, the transition, the driving cell and the load. Mission mode uses `set_case_analysis 0 test_en_i`.

## 3. Pins (119 signal pins incl. clk/rst)

| Pin | Dir | Note |
|---|---|---|
| `clk_i` | in | system clock, 100 MHz |
| `rst_ni` | in | async active-low reset |
| `test_en_i` | in | DFT: forces clock gates open and bypasses the reset synchroniser. **Tie 0 in mission mode** |
| `fetch_enable_i` | in | 1 = core runs after reset (strap) |
| `dbg_rx_i` / `dbg_tx_o` | in/out | debug UART, 115200 baud at 100 MHz |
| `dbg_halted_o` | out | core halted (LED) |
| `uart_rx_i` / `uart_tx_o` | in/out | application UART (16550) |
| `gpio_i[31:0]` / `gpio_o[31:0]` / `gpio_oe_o[31:0]` | in/out/out | `gpio_i[31:30]` = boot mode: 00 SDC flash, 01 direct, 1x debug UART |
| `spi_miso_i`, `spi_mosi_o`, `spi_cs_o[3:0]`, `spi_sck_o` | | SPI master |
| `sdc_miso_i`, `sdc_mosi_o`, `sdc_cs_o[3:0]`, `sdc_sck_o` | | 2nd SPI master (SD card / boot flash) |

GPIO is split into `_i`, `_o` and `_oe`, so the pad ring must build the bidirectional pads (OE = `gpio_oe_o`). The async inputs `dbg_rx_i`, `uart_rx_i` and `gpio_i` all pass through 2-FF synchronisers.

**Clock-frequency dependency:** the debug baud rate is `clk / DBG_CLKS_PER_BIT`. If sign-off is not at 100 MHz, tell us **before** synthesis so the parameter can be changed.

## 4. Memory map

| Region | Base | Size |
|---|---|---|
| Boot ROM | 0x0000_1000 | 4 KB (reset fetch at 0x1080) |
| SDC (SPI 2) | 0x0001_3000 | APB |
| CLINT | 0x0200_0000 | |
| PLIC | 0x0C00_0000 | |
| UART | 0x1000_0000 | byte access only |
| SPI | 0x1004_0000 | word access only |
| GPIO | 0x1006_0000 | word access only |
| IRAM | 0x8000_0000 | 16 KB physical (64 KB window) |
| DRAM | 0x8001_0000 | 8 KB physical (64 KB window) |

An unmapped address or a wrong access size returns an AHB ERROR, which traps with mcause 5 or 7.

## 5. DFT

- There is **no scan chain** in the RTL. `test_en_i` only opens the clock gates and bypasses the reset synchroniser.
- If scan is inserted, use `test_en_i` as the scan/test-mode signal. All flops use one clock domain. The 32 clock gates already take the test enable on SE.
- The design has 32 latches, all inside ICG cells once mapped. No other latches.

## 6. Verification status (RTL, Questa, final RTL)

`verification/soc_level/run_all.py --sim questa --cg both`: 10 suite runs pass, 0 fail.

| Suite | Result |
|---|---|
| Test_via_sdc (SD-card boot) | 4/4 |
| Test_boot_programs (boot ROM paths) | 12/12 |
| Test_arch (riscv-arch-test RV32IC + Zicsr subset) | 65/65, CG on and off |
| Test_periph_irq (irq, periph, gpio32, exc, FreeRTOS soak) | 5/5 ×2 |
| Test_bus (3-master bus, ERROR responses, debug host) | 1/1 ×2 (30 checks) |
| Test_random (100 random programs vs Spike) | 100/100 ×2 |

Code coverage (Questa) on our own RTL, excluding the debug units: 87% statements, 79% branches.

Also checked: `handover/check/tb_bootrom_eq.sv` confirms the synthesis ROM matches `rom.hex` (1024/1024 words). `neumann_soc_synth.f` lints clean.

## 7. Known errata (accepted, not bugs for PD)

- `wfi` executes as a NOP; the core only sleeps if `fetch_enable_i`=0.
- No mie/mip/mscratch/mtval CSRs: they read 0 and do not trap.
- An instruction-fetch bus error is ignored.
- A misaligned store whose 1st half faults still writes the 2nd half.
- LOAD funct3 110/111 execute as custom loads and do not raise an illegal-instruction trap.

## 8. Please send back

1. Synthesised netlist (`.v`) plus the SDC used, for each run.
2. **SDF** (min/typ/max) and the macro/ICG simulation models, so we can run **gate-level sim** with our Questa testbenches. This is the most important item: first-silicon confidence depends on GLS.
3. Timing reports: setup and hold, worst 100 paths, and the achieved frequency.
4. Area per hierarchy (core, uncore, IRAM, DRAM, ROM) and a power estimate.
5. Memory-compiler datasheets and the final macro wrappers.
6. Post-PD: LVS/DRC clean report and the final GDS name/version.

## 9. Nightly regression 

From `neumann_soc/verification/soc_level/`: `python run_all.py --sim questa --cg both`. This needs Questa, Python 3 and a riscv32 GCC. All suites ship `prebuilt/` images, so GCC is only needed with `--rebuild`. Logs are written to `TEST/run_all_logs/`, and a suite passes when its "PASSED a / b" line has a == b.

The testbenches back-door load IRAM, DRAM and ROM by RTL hierarchy. For a **netlist** regression, those load paths must point at the macro models. We will adapt them once the macro names are known.

## 10. Integrity

`handover/MANIFEST.md5` lists the md5 of every file in the bundle. Check it with `md5sum -c handover/MANIFEST.md5`, run from `neumann_soc/`.
