# Test_arch — RISC-V architectural tests (riscv-arch-test)

Runs the official RISC-V architectural test suite on the neumann SoC: the rv32i `I`
(38 tests), `C` (27) and `Zifencei` (1) suites. Each test runs, writes its results into a
**signature** area in memory, and the signature is compared word by word with the
reference output shipped with the suite (made by the suite maintainers with the reference
model). No ISA simulator is needed.

## Flow

```
riscv-arch-test/rv32i_m/<suite>/src/<test>.S  + env/model_test.h (our target macros)
        │ build.py: GCC or clang, -march=rv32i / rv32ic / rv32i_zifencei
        ▼
build/<id>_iram.hex (from 0x8000_0000, entry 0x8000_0080)   build/<id>_dram.hex (.data + signature)
        │ tb_arch.sv: back-door preload, boot pins gpio_i[31:30] = 01 (direct boot)
        ▼
boot ROM ──► jump 0x8000_0080 ──► test code ──► RVMODEL_HALT:
        DRAM+0x10 = begin_signature, +0x14 = end_signature, +0x00 = 0xC0DE0001
        │ tb dumps the signature words → build/<id>.signature
        ▼
tests.py: compare with riscv-arch-test/.../references/<test>.reference_output → PASS / FAIL
```

## Memory maps

| Map | IRAM | DRAM | Used by |
|---|---|---|---|
| `std` | 16 KB at `0x8000_0000` (the chip) | 8 KB at `0x8001_0000` | 58 tests |
| `big` | 2 MB window (`IRAM_PHYS = 0x1F_FFFF`) | 8 KB at `0x8020_0000` | `beq bge bgeu blt bltu bne jal-01` |

The 7 `big` tests check branch / jump offsets up to ±1 MB, so their code is 160 KB to
1.7 MB and cannot fit the chip's 64 KB IRAM window. For them only, `config_big/config.vh`
(a copy of `config/config.vh` with a 2 MB IRAM window and DRAM moved up) is put first on the
include path. The RTL is not changed; the chip uses `config/config.vh`. `build.py` picks
the map per test (std if it fits) and records it in `build/manifest.txt`.

## Files

| File | What it is |
|---|---|
| `riscv-arch-test/` | suite subset, tag 2.7.4, unmodified (`SOURCE.txt`, licenses) |
| `env/model_test.h` | target macros: halt, signature bounds, `SIGBASE` |
| `config_big/config.vh` | test-only platform config for the 7 big tests |
| `tb/tb_arch.sv` | testbench: preload, direct boot, signature dump |
| `tb/dpi_getenv.c` | DPI stub for Verilator |
| `tests.py` | test list, maps, plusargs, skip list, signature compare |
| `build.py` | builds ROM + all tests; **no compiler → copies `prebuilt/`** |
| `prebuilt/` | ready-made hex images + manifest (same as a fresh build) |
| `run_questa.py` | Questa (Windows / Linux) |
| `run_verilator.py` | Verilator 5 (Linux / Docker), CLK_GATING 1 and 0, parallel |

## Run

```
python run_questa.py                 # all tests, CLK_GATING=1
python run_questa.py I               # one suite: I | C | Zifencei
python run_questa.py add-01 c.li     # some tests (names as in src/, with or without suite prefix)
python run_questa.py --cg 0          # CLK_GATING=0
python run_questa.py C-cli-01 --gui  # waves
python run_verilator.py -j 8         # Verilator, both CLK_GATING values
python run_verilator.py --quick      # CLK_GATING=1 only
```
Report: `build/report_questa.txt` / `build/report.txt`; per-test logs and signatures in `build/`.

## Not run

| Test / suite | Why |
|---|---|
| `C-cebreak-01` (built, skipped) | needs a trap handler with `mscratch` / `mtval`; on this core `EBREAK` enters debug mode |
| `privilege/` (ecall, ebreak, misaligned) | need `mtval` and misaligned-access traps; this core has no `mtval` and splits misaligned accesses instead of trapping |
| `M`, `F`, `K` | extensions not implemented |

## Result (2026-11-21)

`I` 38/38, `C` 26/26, `Zifencei` 1/1 — **130 / 130** runs in Verilator 5 (65 tests ×
CLK_GATING 1 and 0). Questa 2024.1: 65/65, with CLK_GATING 1 and 0.
