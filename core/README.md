# rv32i core (clean copy for SoC integration)

Only the processor core and the machine timer. No testbenches, no verification
folders, no SoC glue. This is the starting point for the AHB-Lite SoC.

## Contents

| Path | What |
|---|---|
| `rtl/core/` | RV32IC + Zicsr core, machine mode, 2-stage pipeline (zero-riscy derived) |
| `rtl/core/cluster_clock_gating.sv` | Latch-free clock gate (negedge flop + AND) |
| `rtl/peripherals/rv32i_timer.v` | Machine timer: 64-bit `mtime` / `mtimecmp`, CLINT offsets (`0x4000`, `0xBFF8`), `irq_o = mtime >= mtimecmp` |
| `core.f` | File list |

## Core parameters (`rv32i_core`)

| Parameter | Default | Meaning |
|---|---|---|
| `N_PERF_CNT` | 2 | Performance counters |
| `CLK_GATING` | 1 | 1 = clock gates on, 0 = all gates removed (register file uses enable flops) |

## Core bus ports

Instruction and data ports use an OBI-style req/gnt/rvalid handshake. They will be
connected to AHB-Lite through an adapter in the SoC.

## Changes in this copy compared with zero-riscy

- FENCE = NOP, FENCE.I = jump to PC+4 (flushes prefetch)
- Load/store access fault trap (mcause 5 / 7) on `data_err_i`
- No latches: flop-based clock gate, flop register file, `CLK_GATING` switch
- Timer interrupt goes to `irq_i` with id 7 (mcause `0x8000_0007`)
