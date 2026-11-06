# RV32I rv32i — RISC-V Core

A Verilog implementation of the **RV32I** RV32I core — a minimal, area-optimized 32-bit RISC-V processor — with a UART debug bridge, simulation memories, testbenches, and a Python-based toolchain for assembly, golden-model verification, and RTL simulation.

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│  top_soc                                         │
│  ┌────────────────────────┐  ┌────────────────┐  │
│  │   rv32i_core       │   │  │uart_debug_unit │  │
│  │  ┌─────┐  ┌─────────┐  │  │  ┌────┐ ┌────┐ │  │
│  │  │ IF  │→ │  ID/EX  │  │  │  │ RX │ │ TX │ │  │
│  │  │stage│  │  stage  │  │  │  └────┘ └────┘ │  │
│  │  └─────┘  └─────────┘  │  │    debug bus   │  │
│  │    ↕          ↕        │  │    mem master  │  │
│  │  fetch    ALU / LSU    │  └───────┬────────┘  │
│  │  fifo     reg file     │          │           │
│  └────────┬───────────────┘    ┌─────┴─────┐     │
│           │ instr bus          │  data bus │     │
│           │                    │  arbiter  │     │
└───────────┼────────────────────┼───────────┼─────┘
            ↕                    ↕           ↕
       ┌─────────┐         ┌─────────┐
       │instr_mem│         │data_mem │
       │  (ROM)  │         │ (RAM)   │
       └─────────┘         └─────────┘
```

**Key features:**
- RV32I base integer instruction set (no M/C extensions in the core pipeline)
- Compressed instruction decoder (RV32C decode → RV32I expansion)
- OBI-style memory interface (req/gnt/rvalid handshake)
- UART debug unit: halt, resume, read GPRs, read/write memory over serial
- Fully synchronous, single-clock design

## Directory Structure

```
RV32I_rv32i/
├── README.md                 ← you are here
├── rtl/
│   ├── core/                 ← CPU pipeline, ALU, decoder, register file, etc.
│   │   ├── rv32i_core.v          (top-level core)
│   │   ├── rv32i_if_stage.v      (instruction fetch)
│   │   ├── rv32i_id_stage.v      (instruction decode)
│   │   ├── rv32i_ex_block.v      (execute stage)
│   │   ├── rv32i_Alu.v           (ALU)
│   │   ├── rv32i_decoder.v       (main decoder)
│   │   ├── rv32i_compressed_decoder.v  (RV32C → RV32I)
│   │   ├── rv32i_controller.v    (pipeline control / hazards)
│   │   ├── rv32i_cs_registers.v  (CSR bank)
│   │   ├── rv32i_load_store_unit.v    (LSU)
│   │   ├── rv32i_register_file.v      (32×32 register file)
│   │   ├── rv32i_debug_unit.v         (debug interface)
│   │   ├── rv32i_int_controller.v     (interrupt controller)
│   │   ├── rv32i_prefetch_buffer.v    (instruction prefetch)
│   │   ├── rv32i_fetch_fifo.v         (fetch FIFO)
│   │   ├── rv32i_imm_gen.v            (immediate generator)
│   │   └── rv32i_defines.vh           (global defines)
│   ├── soc/                  ← SoC integration wrappers
│   │   ├── top_soc.v                 (core + debug unit + bus arbiter)
│   │   ├── uart_debug_unit.v         (UART-to-debug-bus bridge)
│   │   ├── uart_rx.v / uart_tx.v     (UART transceiver)
│   │   └── cluster_clock_gating.v    (ICG cell for simulation)
│   └── mem/                  ← Simulation memory models
│       ├── instr_mem.v               (instruction ROM, $readmemh)
│       └── data_mem.v                (byte-writable data RAM)
├── tb/                       ← Testbenches
│   ├── tb_sort.v                     (bubble sort, backdoor + UART check)
│   └── tb_fib.v                      (Fibonacci, backdoor + UART check)
├── sw/                       ← Software toolchain & test programs
│   ├── asm/                  ← Assembly source files (.s)
│   │   ├── rv32i_compliance.s        (★ full ISA compliance test)
│   │   ├── sort.s, fib.s, gcd.s, mul.s, primes.s, strlen_rev.s
│   ├── hex/                  ← Assembled hex images (.hex)
│   │   ├── sort.hex, fib.hex, ...
│   ├── rv32i_asm.py                  (minimal two-pass RV32I assembler)
│   └── iss.py                        (instruction-set simulator / golden model)
├── scripts/                  ← Automation scripts
│   ├── assemble.py                   (batch assemble all .s → .hex)
│   ├── iss_verify.py                 (ISS golden-model verification)
│   └── run_all.py                    (master: assemble → ISS → RTL sim)
├── peripherals/              ← APB peripheral IP blocks
│   ├── gpio/                         (32-bit GPIO with edge interrupts)
│   │   └── apb_gpio.v
│   ├── timer/                        (32-bit timer/counter with prescaler)
│   │   └── apb_timer.v
│   ├── spi_master/                   (APB SPI master controller)
│   └── README.md                     (register maps & integration guide)
├── sim/                      ← Simulator configuration
│   ├── core.f                        (Verilog source filelist)
│   └── run.do                        (QuestaSim/ModelSim run script)
```

## Prerequisites

| Tool | Required For | Install |
|------|-------------|---------|
| **Python 3.8+** | Assembly, ISS, automation scripts | [python.org](https://python.org) |
| **Icarus Verilog** | Free RTL simulation | `choco install iverilog` or [iverilog.icarus.com](http://iverilog.icarus.com) |
| **QuestaSim / ModelSim** | Commercial RTL simulation | Intel/Siemens EDA |

> **Note:** Python scripts have **zero external dependencies** — only the Python standard library is used.

## Quick Start

### 1. Assemble all test programs

```bash
python scripts/assemble.py
```

This assembles every `.s` file in `sw/asm/` into a `.hex` file in `sw/hex/`.

### 2. Verify with the ISS golden model

```bash
python scripts/iss_verify.py
```

Runs each `.hex` through the instruction-set simulator and checks:
- Program halts cleanly (no infinite loop / trap)
- Done flag `0xC0DE0001` at address `0x000`
- No exception marker at address `0x004`
- Program-specific data checks (sorted array, Fibonacci sequence, GCD result)

### 3. Run RTL simulation

**With Icarus Verilog (free):**
```bash
python scripts/run_all.py --sim iverilog
```

**With QuestaSim:**
```bash
python scripts/run_all.py --sim questa
# or directly:
vsim -c -do sim/run.do
```

**Skip RTL sim (assemble + ISS only):**
```bash
python scripts/run_all.py --sim skip
```

### One-command full flow

```bash
python scripts/run_all.py
```

This automatically: assembles → ISS verifies → detects your simulator → runs RTL sim → prints a summary.

## Test Programs

### rv32i_compliance.s — Full ISA Compliance Test ★

The most important test. Systematically exercises **every RV32I instruction** with 41 self-checking sub-tests:

| Group | Tests | Instructions Covered |
|-------|-------|---------------------|
| R-type ALU | 0–12 | `add`, `sub` (pos & neg), `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt` (taken/not), `sltu` |
| I-type ALU | 13–21 | `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli`, `srai` |
| Load/Store | 22–26 | `sw`+`lw`, `sb`+`lbu`, `lb` sign-ext, `sh`+`lhu`, `lh` sign-ext |
| Branches | 27–33 | `beq` (taken+not), `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Upper+Jump | 34–37 | `lui`, `auipc`, `jal` (link verify), `jalr` (call/return) |
| Edge cases | 38–40 | x0 immutability, integer overflow wrap, logical vs arithmetic shift |

Run it alone:
```bash
python scripts/assemble.py rv32i_compliance
python scripts/iss_verify.py rv32i_compliance --verbose
```

### Other Test Programs

| Program | Description | Key Instructions Exercised |
|---------|-------------|---------------------------|
| `sort.s` | Bubble sort of 12 signed integers | `lui`, `add`, `slli`, `lw`, `sw`, `beq`, `bge`, `jal` |
| `fib.s` | Iterative Fibonacci (first 12 numbers) | `add`, `addi`, `sw`, `bge`, `jal` |
| `gcd.s` | GCD(1071, 462) = 21 via subtraction | `sub`, `beq`, `blt`, `jal` |
| `mul.s` | Shift-and-add multiplication (no M ext) | `slli`, `srli`, `andi`, `add`, `beq`, `jalr` |
| `primes.s` | Prime sieve up to 43 | `sub`, `blt`, `bge`, `jalr` |
| `strlen_rev.s` | String length + reverse | `lb`, `lbu`, `sb`, `jalr` |

## Writing a New Test Program

1. **Create the assembly file** in `sw/asm/`:

```asm
# my_test.s — description of what it tests
    .org 0x80
    j    _start
    j    trap_illegal
    j    trap_ecall
    j    trap_lsuerr

_start:
    # ... your test code ...
    
    # When done, write the done flag and park:
    li   x8, 0xC0DE0001
    sw   x8, 0(x0)
halt:
    j    halt

# Exception handlers (copy from any existing test):
trap_illegal:
    li   x9, 0xBAD00001
    j    trap_store
trap_ecall:
    li   x9, 0xBAD00002
    j    trap_store
trap_lsuerr:
    li   x9, 0xBAD00003
trap_store:
    sw   x9, 4(x0)
trap_halt:
    j    trap_halt
```

2. **Assemble it:**
```bash
python scripts/assemble.py my_test
```

3. **Test with the ISS:**
```bash
python sw/iss.py sw/hex/my_test.hex --all --signed
```

4. **(Optional)** Add expected results to `scripts/iss_verify.py` in the `EXPECTED` dict.

5. **(Optional)** Create a testbench `tb/tb_my_test.v` for RTL simulation.

## Memory Map Convention
All test programs follow this convention:

| Address | Purpose |
|---------|---------|
| `0x000` | Status word — `0xC0DE0001` when program completes |
| `0x004` | Trap marker — non-zero if an exception fired |
| `0x080` | Reset vector (boot address + `0x80`) |
| `0x084` | Illegal instruction exception vector |
| `0x088` | ECALL exception vector |
| `0x08C` | Load/store error exception vector |
| `0x100+` | Program data region |

## UART Debug Protocol

The UART debug unit accepts commands over the serial link (default 115200 baud on FPGA, 8 clks/bit in simulation):

| Command | Byte(s) Sent | Response | Description |
|---------|-------------|----------|-------------|
| HALT | `0x01` | `0x90` (ACK) | Halt the core |
| RESUME | `0x02` | `0x91` (ACK) | Resume execution |
| STATUS | `0x04` | 1 byte (bit 0 = halted) | Query halt status |
| READ GPR | `0x10`, `reg[4:0]` | 4 bytes (LSB first) | Read register x0–x31 |
| READ MEM | `0x40`, `addr[31:0]` (LSB first) | 4 bytes (LSB first) | Read 32-bit word from data bus |
| WRITE MEM | `0x80`, `addr[31:0]`, `data[31:0]` | `0x92` (ACK) | Write 32-bit word to data bus |

## Supported RV32I Instructions

The assembler (`sw/rv32i_asm.py`) and core support:

- **R-type:** `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
- **I-type:** `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
- **Load:** `lb`, `lh`, `lw`, `lbu`, `lhu`
- **Store:** `sb`, `sh`, `sw`
- **Branch:** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
- **Jump:** `jal`, `jalr`
- **Upper:** `lui`, `auipc`
- **Pseudo-ops:** `li` (load immediate), `nop`, `j` (unconditional jump)


