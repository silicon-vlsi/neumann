# TEST — verification of the neumann SoC

One sub-folder per test suite. Each holds its programs, golden (expected) results,
testbench, ready-made images and run scripts, kept separate from the RTL. Device models
(SPI flash, SPI memory) live only here, never in `rtl/`.

All scripts are Python 3 (no bash needed) and run from the suite's own folder, on Windows
(PowerShell / cmd) or Linux. Without a RISC-V compiler, `build.py` copies `prebuilt/`
into `build/`, so Questa on Windows needs nothing else. Each suite's `README.md` has the
full details.

## Suites

| Folder | Program loaded via | What it checks |
|---|---|---|
| `Test_via_sdc/` | SPI flash on the SDC port, copied by the boot ROM (boot pins `00`) | flash boot of a GCD program (32 results vs golden); bad magic / length / checksum images rejected with `BOOT_STATUS` E1 / E2 / E3 and fallback to debug boot |
| `Test_boot_programs/` | SDC flash **and** debug UART (boot pins `00` and `1x`) | 6 programs (gcd, sort, crc32, sieve, mathx, FreeRTOS) booted both ways, results vs golden |
| `Test_arch/` | back-door preload, direct boot (`01`) | official riscv-arch-test 2.7.4, rv32i `I` (38), `C` (26 run, `cebreak` skipped), `Zifencei` (1); signatures vs the suite's reference outputs |
| `Test_periph_irq/` | back-door preload, direct boot (`01`) | `irq`: interrupt priority MEI > MSI > MTI, PLIC claim / complete / tie / threshold, `mtimecmp` rewrites, WFI wake, MSI + GPIO + timer stress. `periph`: UART loopback, SPI to a memory model, GPIO edge / level / write-1-to-clear. `gpio32`: all 32 pins, walking 1 / 0, `out_xor`, input / output enables, all-pin interrupts. `exc`: ecall / illegal-instruction traps with exact `mcause` / `mepc`, `mstatus` stacking, CSR edges. `rtos_soak`: 12.8 M-clock FreeRTOS run, no tick drift, no lost wake-ups |
| `Test_bus/` | back-door preload, direct boot (`01`) + debug unit traffic | misaligned loads / stores (split by the core), bus errors on unmapped addresses (load / store access fault), ROM write ignored, address aliasing, three AHB masters (fetch, LSU, debug unit) at once |
| `Test_random/` | back-door preload, direct boot (`01`) | 100 random RV32IC programs (40 blocks × 25 instructions, register dump after every block), signature compared word by word with Spike |

## Results

Final RTL, 2026-11-22.

| Suite | Verilator 5 (CLK_GATING 1 and 0) | Questa 2024.1 (`run_all.py --cg both`) |
|---|---|---|
| `Test_via_sdc` | 8 / 8 | 4 / 4 (CLK_GATING 1; no CLK_GATING 0 option) |
| `Test_boot_programs` | 24 / 24 | 12 / 12 (CLK_GATING 1; no CLK_GATING 0 option) |
| `Test_arch` | 130 / 130 | 65 / 65 + 65 / 65 |
| `Test_periph_irq` | 10 / 10 | 5 / 5 + 5 / 5 |
| `Test_bus` | 2 / 2 | 1 / 1 + 1 / 1 |
| `Test_random` (vs Spike) | rand_1..10: 20 / 20 | 100 / 100 + 100 / 100 |

Questa `run_all.py --cg both`: **10 suite runs passed, 0 failed** (2 skipped: no CLK_GATING 0
option), 1013 s in total.

## Run everything

`run_all.py` runs every suite one after the other and prints one summary table
(full output per suite in `run_all_logs/`):

```
python run_all.py                          # Questa, CLK_GATING=1, all 6 suites
python run_all.py --cg 0                   # Questa, CLK_GATING=0 (suites that support it)
python run_all.py --cg both                # Questa, CLK_GATING 1 then 0
python run_all.py -s Test_arch Test_bus    # some suites
python run_all.py --stop                   # stop at the first failing suite
python3 run_all.py --sim verilator         # Verilator (Docker), CLK_GATING 1 and 0
python3 run_all.py --sim verilator --quick # Verilator, CLK_GATING 1 only
```
The default simulator is Questa when `vsim` is on PATH, otherwise Verilator.
`Test_via_sdc` and `Test_boot_programs` have no Questa CLK_GATING=0 option and are skipped there.

Full Verilator regression: `run_all.py --sim verilator` — 6 / 6 suites, 188 / 188 runs PASS.

## Commands

### Questa (Windows or Linux; `vlib` / `vlog` / `vsim` on PATH)

```
cd TEST\Test_via_sdc
python run_questa.py                     # 4 tests: pass, e1, e2, e3
python run_questa.py pass --gui          # one test with waves

cd TEST\Test_boot_programs
python run_questa.py                     # 6 programs x {sdc, dbg} = 12 runs
python run_questa.py -p rtos -b sdc      # some programs / boot ways
python run_questa.py -p gcd -b dbg --gui

cd TEST\Test_arch
python run_questa.py                     # 65 tests, CLK_GATING=1
python run_questa.py --cg 0              # CLK_GATING=0
python run_questa.py C                   # one suite: I | C | Zifencei
python run_questa.py add-01 C-cli-01     # some tests
python run_questa.py C-cli-01 --gui

cd TEST\Test_periph_irq
python run_questa.py                     # irq, periph, gpio32, exc, rtos_soak; CLK_GATING=1
python run_questa.py --cg 0
python run_questa.py -p irq --gui

cd TEST\Test_bus
python run_questa.py                     # bus, CLK_GATING=1
python run_questa.py --cg 0

cd TEST\Test_random
python run_questa.py                     # rand_1..rand_100 vs Spike goldens, CLK_GATING=1
python run_questa.py --cg 0
python run_questa.py 3 --gui
```
`Test_via_sdc` and `Test_boot_programs` run Questa with CLK_GATING=1 only.

### Verilator 5 (Linux / Docker; needs make + g++)

```
cd TEST/Test_via_sdc        && python3 run_verilator.py          # 4 tests x CLK_GATING 1, 0
cd TEST/Test_boot_programs  && python3 run_verilator.py -j 4     # 12 runs x CLK_GATING 1, 0
cd TEST/Test_arch           && python3 run_verilator.py -j 8     # 65 tests x CLK_GATING 1, 0
cd TEST/Test_periph_irq     && python3 run_verilator.py          # 5 programs x CLK_GATING 1, 0
cd TEST/Test_bus            && python3 run_verilator.py          # 1 program x CLK_GATING 1, 0
cd TEST/Test_random         && python3 run_verilator.py          # 100 programs x CLK_GATING 1, 0
```
Common options: `--quick` (CLK_GATING=1 only), `--no-build` (reuse `build/`);
`Test_boot_programs` also takes `-p` / `-b`, `Test_arch` takes test names or a suite.

Logs and reports go to each suite's `build/` folder (`questa_*.log`, `sim_cg*_*.log`,
`report*.txt`).

### Spike (Docker; makes the Test_random goldens, once)

```
cd TEST/Test_random         && python3 run_spike.py
```

## Layout of a test folder

```
programs/   test programs (C / assembly); results written to DRAM
golden/     expected results (written from the spec or computed independently in Python)
tb/         testbench, device models, DPI stub
prebuilt/   ready-made images (no compiler needed)
build.py, tests.py, run_questa.py, run_verilator.py, README.md
```
