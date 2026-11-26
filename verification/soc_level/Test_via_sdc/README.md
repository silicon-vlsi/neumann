# Test_via_sdc — program the SoC from a SPI flash on the SDC port

The program is **not** preloaded. Only the boot ROM is loaded (back-door, it is a ROM).
The ROM reads the program from a SPI flash on the SDC pins, copies it into IRAM/DRAM and
runs it. The testbench then compares the program's results with golden values.

## Flow

```
flash.hex ──► spiflash.v (flash chip model, tb only)
                 │  sdc_sck_o / sdc_mosi_o / sdc_miso_i / sdc_cs_o[0]
                 ▼
             SDC = uncore spi_apb @ 0x0001_3000  ◄─APB─ AHB ◄─ ebu3 ◄─ obi2ahb_d ◄─ core LSU
                 ▲
   boot ROM (0x1080, gpio_i[31:30] = 00):
     0xAB, wait, CSMODE=HOLD, 0x03 00 00 00, read header,
     copy IRAM image -> 0x8000_0000, DRAM image -> 0x8001_0040,
     check checksum, release CS, BOOT_STATUS = 0xB00700AA, jump to entry
                 ▼
   core runs gcd from IRAM: start.S -> main() -> results to DRAM 0x8001_1000
     -> SIG_STATUS 0x8001_0000 = 0xC0DE0001
                 ▼
   testbench: RESULT[i] == golden/gcd.golden[i] ?  -> RESULT: PASS / FAIL
```

## Files

| File | What it is |
|---|---|
| `programs/gcd.c` | binary GCD (shifts/subtracts, RV32I only) over 32 input pairs; inputs in `.data` (so the DRAM part of the copy is tested), results to `0x8001_1000 + 4i`, count to `0x8001_0FFC` |
| `programs/gen_gcd.py` | makes `programs/gcd_inputs.h` (input pairs) and `golden/gcd.golden` (Python `math.gcd`). Edge cases: 0, equal, powers of 2, 0xFFFFFFFF, Fibonacci, primes + random |
| `golden/gcd.golden` | expected results, one hex word per line |
| `tools/mkflash.py` | `iram.bin` + `dram.bin` → `flash.hex` (header + images, one byte per line). `--corrupt magic|length|checksum` makes bad images |
| `flash/spiflash.v` | SPI flash model from PicoSoC (ISC license, unmodified, see `flash/SOURCE.txt`) |
| `tb/tb_sdc_boot.sv` | testbench: SoC + flash on the SDC pins, boot pins `00`, checks results / rejection |
| `tb/dpi_getenv.c` | DPI stub for the uncore's `getenvval` import |
| `build.py` | builds boot ROM (also updates `sw/boot/rom.hex`), gcd, and 4 flash images into `build/`. Uses the first of `riscv64-unknown-elf-gcc`, `riscv32-unknown-elf-gcc`, `riscv-none-elf-gcc`, clang/lld; **no compiler → copies `prebuilt/`** |
| `prebuilt/` | ready-made `rom.hex`, `flash_*.hex`, `gcd.dis` (same as a fresh build) so Questa on Windows needs no RISC-V compiler |
| `run_questa.py` | build + Questa (vlib/vlog/vsim on PATH), Windows or Linux |
| `run_verilator.py` | build + Verilator 5, 4 tests × `CLK_GATING` 1/0 (Linux / Docker) |

## Tests

| `+EXPECT` | Flash image | Pass when |
|---|---|---|
| `pass` | `flash_gcd.hex` | BOOT_STATUS `B00700AA`, program done `C0DE0001`, 32/32 results = golden |
| `e1` | `flash_bad_magic.hex` | BOOT_STATUS `B00700E1`, core stays in ROM (debug-boot wait), CS released |
| `e2` | `flash_bad_length.hex` | BOOT_STATUS `B00700E2`, same |
| `e3` | `flash_bad_checksum.hex` | BOOT_STATUS `B00700E3`, same |

## Run

Python 3 only, no bash needed. From this folder (PowerShell, cmd or Linux):
```
python run_questa.py                  # Questa: build + all 4 tests
python run_questa.py pass             # one test: pass | e1 | e2 | e3
python run_questa.py pass --gui       # Questa GUI with waves
python run_questa.py --no-build       # reuse build/
python run_verilator.py               # Verilator (Docker): 8 runs
python run_verilator.py --quick       # 4 runs, CLK_GATING=1
python build.py                       # build only
```
Logs: `build/questa_<test>.log`, `build/vlog.log`, `build/sim_*.log`. Disassembly: `build/gcd.dis`.

Result (Verilator 5.020, clang build): 8/8 PASS. gcd image 756 bytes, boot copy done at
~34 k cycles, program done at ~47 k cycles (100 MHz clock, SCK 25 MHz).
Not run here: Questa, GCC build (scripts written for them; please run in your setup).

## Your own program

1. Write `programs/foo.c` with `#include "soc.h"`, `main()` returns `SIG_PASS`, and a `c_trap()`.
2. Build like gcd in `build.py` (start.S + foo.c, `sw/app/link_app.ld`, objcopy `.vectors .text`
   → iram.bin, `.data` → dram.bin), then `tools/mkflash.py iram.bin dram.bin foo_flash.hex`.
3. Simulate with `+firmware=foo_flash.hex` and your own golden file.
