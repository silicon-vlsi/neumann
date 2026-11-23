# Test_boot_programs — boot several programs (incl. FreeRTOS) both ways and check them

Each program is loaded into an empty SoC (only the boot ROM is preloaded) in two ways,
runs, and its results are compared with golden values computed in Python:

| Boot | Boot pins `gpio_i[31:30]` | How the program gets in |
|---|---|---|
| `sdc` | `00` | SPI flash model on the SDC pins (CS0); the boot ROM copies it into IRAM/DRAM (see `../Test_via_sdc`) |
| `dbg` | `10` | the testbench acts as the host PC on the debug UART: `WMEM` every word of IRAM + DRAM, `RMEM` read-back of first/last word, then writes the entry `0x8000_0080` to the mailbox `0x8001_0004`; the ROM jumps. Core is not halted (debug writes while it runs the ROM poll loop) |

## Programs

| Program | What it exercises | Results |
|---|---|---|
| `gcd` | binary GCD, 32 pairs incl. 0, 2^31, 0xFFFFFFFF, Fibonacci | 32 gcds |
| `sort` | insertion sort, unsigned (`bltu`) and signed (`blt`), 48 words incl. duplicates/sign bit | 48 sorted + 8 signed samples |
| `crc32` | bitwise CRC-32, `lb/lbu/lh/lhu/sb/sh`, unaligned byte buffers, `.rodata` in IRAM read by the LSU | 8 words |
| `sieve` | primes < 2048, 2 KB byte array in `.bss`, nested loops | count, sum, samples |
| `mathx` | software mul/div (no M extension), 64-bit add with carry, Fibonacci | 27 words |
| `rtos` | **FreeRTOS V11.1** (unmodified kernel, official RISC-V port): 7 tasks + idle, CLINT tick interrupt (MTI), `ecall` yield, queue, mutex, task notification, `vTaskDelay`, preemption and time slicing | 9 words, see `programs/rtos/rtos_test.c` |

Common for all: results at `0x8001_1C00 + 4i`, count at `0x8001_1BFC`, done =
`SIG_STATUS 0x8001_0000 = 0xC0DE0001`; a trap writes `0xBAD0F000 | mcause` (FreeRTOS:
`0xBAD0A000` assert, `0xBAD0B000` stack overflow, `0xBAD0C000` malloc, `0xBAD0E000|id` unexpected interrupt).

FreeRTOS port notes (also in `freertos/SOURCE.txt`): mtime `0x0200_BFF8`, mtimecmp `0x0200_4000`,
tick = 10 000 clocks. The core has no `mie` CSR; the port's `csrs mie` is a no-op on this core
(unknown CSRs read 0, writes ignored), interrupts are gated by `mstatus.MIE` + mtimecmp.
Every vector entry in `programs/rtos/start_rtos.S` jumps to `freertos_risc_v_trap_handler`.

## Files

| File | What it is |
|---|---|
| `programs/*.c`, `programs/test.h` | test programs, common result/trap definitions |
| `programs/gen_golden.py` | input headers (`*_inputs.h`) + `golden/<program>.golden` (Python: `math.gcd`, `sorted`, `zlib.crc32`, ...) |
| `programs/libc_stub.c` | `memset/memcpy/memmove/memcmp`, `__mulsi3/__muldi3/__udivsi3/...` (linked with `-nostdlib`) |
| `programs/rtos/` | `rtos_test.c`, `FreeRTOSConfig.h`, `start_rtos.S`, minimal `libc_inc/` headers |
| `freertos/` | FreeRTOS kernel subset, unmodified, MIT (`LICENSE.md`, `SOURCE.txt`) |
| `tb/tb_boot.sv` | testbench: `+BOOT=sdc|dbg`, flash model, debug-UART host driver, result check |
| `build.py` | builds ROM + all programs into `build/` (`<p>_iram.hex`, `<p>_dram.hex`, `flash_<p>.hex`, `<p>.dis`); checks they fit. No compiler → copies `prebuilt/` |
| `prebuilt/` | ready-made images (clang build) so Questa on Windows needs no RISC-V compiler |
| `tests.py` | test list + plusargs, shared by the run scripts |
| `run_questa.py`, `run_verilator.py` | run the matrix programs × boots |

Uses `../Test_via_sdc/flash/spiflash.v` and `../Test_via_sdc/tools/mkflash.py`.

## Run

From this folder (PowerShell, cmd or Linux):
```
python run_questa.py                         # 6 programs x 2 boots = 12 runs
python run_questa.py -p rtos -b sdc          # one run
python run_questa.py -p rtos gcd -b dbg      # programs gcd + rtos over the debug UART
python run_questa.py -p rtos -b sdc --gui    # waves
python run_questa.py --no-build              # reuse build/
python run_verilator.py --quick -j 4         # Verilator (Docker), 12 runs, 4 in parallel
python run_verilator.py                      # 24 runs (CLK_GATING 1 and 0)
python build.py                              # build only
```
Pass = every run prints `RESULT: PASS`, the script ends with `PASSED n / n`.
Logs: `build/questa_<program>_<boot>.log`, `build/sim_cg<g>_<program>_<boot>.log`.

Run time: SDC boot ~45 clocks per byte (rtos 9.6 KB ≈ 0.5 M cycles to load); debug-UART boot
~1600 clocks per word (rtos ≈ 4 M cycles). Start with `-p gcd` to check the setup, then the rest.

Status (Verilator 5.020, clang 18 images = `prebuilt/`): **24/24 PASS** — 6 programs × {sdc, dbg} ×
`CLK_GATING` {1, 0}. FreeRTOS: ~184 k cycles from boot to done (16 ticks).
Questa: not run here.
