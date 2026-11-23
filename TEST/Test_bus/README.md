# Test_bus — bus corner cases

One program (`programs/bus.c`), preloaded by the testbench (direct boot, boot pins `01`).
Results go to DRAM `0x8001_1C00 + 4i`; `golden/bus.golden` holds the values the RISC-V
spec and AHB-Lite say they should be (written before running, not copied from a simulation).

| Part | What it does | Expected |
|---|---|---|
| Misaligned loads | `lw` at +1/+2/+3, `lh`/`lhu` at +1/+3 (crossing a word), `lw` from IRAM at `0x8000_0082` | correct little-endian values, no trap (the core splits them into two bus accesses) |
| Misaligned stores | `sw` +5, `sh` +11, `sh` +3, read back as aligned words | `0x66000000 0xB2C3D455 0xFF0000A1 0x000000EE`, no trap |
| Bus errors | `lw`/`sw` `0x4000_0000`, `lw` `0x1005_0000` (APB hole), `lb` `0x0000_2000`, `lw` `0x0000_0000`, misaligned `lw` `0x0000_1FFE` (2nd half unmapped) | load access fault (mcause 5) / store access fault (mcause 7), `mepc` = the faulting instruction, `rd` not written |
| ROM write | `sw` to `0x0000_1000` | ignored, no trap, ROM unchanged |
| Aliasing | read `0x8000_4080`, `0x8001_2040` | same as `0x8000_0080`, `0x8001_0040` (16 KB / 8 KB inside 64 KB windows) |
| Three masters | core runs a copy / checksum loop in DRAM (instruction fetch + LSU) while the testbench, as the host PC, writes 64 DRAM words and reads IRAM words through the debug unit, without halting the core | loop never sees a wrong checksum, debug reads correct, all 64 debug words found by the core |

## Run

```
python run_questa.py                 # CLK_GATING=1
python run_questa.py --cg 0
python run_questa.py -p bus --gui
python3 run_verilator.py             # Verilator, CLK_GATING 1 and 0
```

## Result (2026-11-22)

Verilator 5 and Questa 2024.1: 2 / 2 PASS (30 / 30 results, CLK_GATING 1 and 0).
