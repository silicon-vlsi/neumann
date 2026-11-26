# Test_periph_irq — interrupts, peripherals, exceptions, GPIO and RTOS soak

Five programs (`irq`, `periph`, `gpio32`, `exc`, `rtos_soak`), preloaded into IRAM/DRAM by the testbench (direct boot, boot pins `01`),
check the interrupt system and the APB peripherals. Each writes its results to DRAM
`0x8001_1C00 + 4i` (count at `0x8001_1BFC`); the testbench compares them with
`golden/<program>.golden`, which was written from the specifications (RISC-V privileged
spec, PLIC spec, 16550, SiFive SPI / GPIO), not copied from a simulation.

## Testbench connections (`tb/tb_periph.sv`)

| Connection | Purpose |
|---|---|
| `uart_rx_i = uart_tx_o` | application UART loopback |
| SPI `spi_cs_o[0]`, `spi_sck_o`, `spi_mosi_o`, `spi_miso_i` → `tb/spi_mem.sv` | 256-byte SPI memory, mode 0: `0x02 addr data…` write, `0x03 addr` → data… read |
| `gpio_i = gpio_o` on every pin with `gpio_oe_o = 1`; undriven pins read 0 (boot pin 30 reads 1) | GPIO loopback on all 32 pins (software makes its own edges and levels) |
| `gpio_i[31:30] = 01` | direct boot |

## `irq` — interrupt stress (`programs/irq.c`)

| Phase | What it does | Checks |
|---|---|---|
| 1 priority | MSI (msip), MTI (mtimecmp = 0) and MEI (GPIO edge → PLIC) all pending with `mstatus.MIE` = 0, then MIE = 1 | taken in the order 11, 3, 7 (MEI > MSI > MTI); PLIC claim = 3 |
| 2 PLIC claim / complete | GPIO (prio 2) and SPI TX-watermark (prio 1) requesting, polled | pending = `0x48`; claims 3, 6, then 0 while both in progress; pending 0 while in progress; completing a still-requesting source re-pends it; same priority → lowest id first; priority 0 never claimable |
| 3 threshold | GPIO prio 2, MIE = 1 | not taken with threshold 2, taken after threshold 1 |
| 4 timer | periodic tick, handler rewrites `mtimecmp += period`, stops after 20 | exactly 20 ticks; `mtimecmp` moved far before firing → no tick; moved near → exactly 1 |
| 5 WFI | `wfi` loop until the timer handler runs | woken once, at or after the target time |
| 6 stress | timer every 700 clocks while 50 rounds of MSI + GPIO edge are raised back to back with varying gaps | MSI 50, GPIO MEI 50, timer ticks > 0, no unexpected ids |

Note: this core's `WFI` does not stop the clock (it only sleeps when `fetch_enable_i` = 0),
so phase 5 checks that an interrupt is taken from a `wfi` loop and returns correctly.

## `periph` — peripheral directed tests (`programs/periph.c`)

| Block | Checks |
|---|---|
| UART | LCR / divisor-latch read back (27 = 115 200 at 100 MHz); LSR = `0x60` after init; 8-byte polled loopback; 16 bytes into the RX FIFO with nobody reading, all 16 kept; RX-data interrupt through the PLIC (claim 10, IIR = `0xC4`), 8 bytes received in the ISR |
| SPI | write 16 bytes, read back at `sckdiv` 1, 0 and 7; TX watermark `ip[0]` (txmark 1 → 1, 0 → 0); RX watermark `ip[1]` (4 bytes, rxmark 2 → 1; after reading 2 → 0); RX-watermark interrupt through the PLIC (claim 6, correct byte) |
| GPIO | `input_val` via loopback; `rise_ip` / `fall_ip` set on edges; write-1-to-clear (writing 0 or another bit leaves it set); `high_ip` / `low_ip` are level: clearing while the level holds sets them again, clearing after the level goes away keeps them 0; rising-edge interrupt through the PLIC (claim 3); high-level interrupt taken once when the ISR turns `high_ie` off |

## `gpio32` — all 32 GPIO pins (`programs/gpio32.c`)

| Checks |
|---|
| walking 1 and walking 0 over all 32 pins (input via loopback and `output_val` read-back, 128 checks); 0xA5A5A5A5 / 0x5A5A5A5A |
| output invert `out_xor`: pins = `output_val ^ out_xor`, register read-back |
| `input_en` masks pins (0x0000FFFF), `output_en` controls which pins are driven (undriven pins show the board value) |
| `rise_ip`, `fall_ip`, `high_ip`, `low_ip` on all 32 pins at once; write-1-to-clear with pins steady |
| rising edges on pins 31 and 16 through the PLIC (claim 3, both bits seen in the ISR) |

## `exc` — exceptions (`programs/exc.c`)

| Checks |
|---|
| `ecall`: mcause 11, exact `mepc`, `mstatus` in the trap 0x1800 (MIE was 0) / 0x1880 (MIE was 1: MPIE = 1, MIE = 0), after `mret` 0x1888 (MIE restored) |
| illegal instructions, each mcause 2 with exact `mepc`: `0xFFFFFFFF`, 16-bit `0x0000`, `mul` (no M extension), reserved `c.jr x0` (`0x8002`); execution continues after the trap |
| CSR edges: `mepc` read / write; `mcause` keeps only bit 31 and bits 4:0; `mtvec` = 0x8000_0000 |
| `mscratch` and `mtval` read 0 without a trap |

## `rtos_soak` — long FreeRTOS run (`programs/rtos_soak/`)

About 12.8 M clocks (128 ms at 100 MHz, ~1 270 ticks of 10 000 clocks), 9 tasks plus idle:
3 000 items through a 4-entry queue (order and sum checked), 2 x 1 000 increments under a
mutex with a yield inside the critical section, 1 000 ping-pong rounds with task
notifications, 200 x `vTaskDelay(1)`, a never-blocking task for time slicing.
Checks: all counts exact, **no tick drift** (tick count = elapsed `mtime` / 10 000 within
2 ticks), every task stack keeps > 16 free words (overflow check 2 is also on), queue empty.
Uses the FreeRTOS kernel and port from `../Test_boot_programs` (`freertos/`, `programs/rtos/`);
its own `FreeRTOSConfig.h` only raises the heap to 6 000 bytes.

## Run

```
python run_questa.py                 # all 5 programs, CLK_GATING=1 (rtos_soak takes the longest)
python run_questa.py -p exc gpio32   # some programs
python run_questa.py -p irq --gui    # waves
python run_questa.py --cg 0          # CLK_GATING=0
python run_verilator.py              # Verilator, CLK_GATING 1 and 0
```
No RISC-V compiler → `build.py` copies `prebuilt/`.

## Result (2026-11-22)

Verilator 5: **10 / 10 PASS** (5 programs x CLK_GATING 1 and 0).
`irq` 26 results (~105 k cycles), `periph` 37 (~298 k), `gpio32` 18 (~4 k), `exc` 22 (~1.2 k),
`rtos_soak` 11 (~12.8 M cycles). Questa 2024.1 earlier: `irq` + `periph` 2 / 2 with CLK_GATING 1
and 0; gpio32, exc and rtos_soak PASS with CLK_GATING 1 (rtos_soak: 147 s in Questa).

Sanity check of the test itself: with the encoder priority deliberately swapped
(MSI above MEI in `rtl/sys/irq_enc.v`, reverted afterwards) `irq` fails on results 0 and 1.
