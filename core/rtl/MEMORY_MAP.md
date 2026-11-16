# Memory map and addresses — rv32i "neumann" core / 1TOPS AHB-Lite SoC

Status: core part = matches current RTL in this folder.
SoC part = planned, taken from the IIT-BBSR 1TOPS reference SoC. Not built yet; sizes still to agree with Saroj Sir.

---

## 1. Core: reset and trap vectors

Vectors are `base + offset`, where `base` is a 256-byte aligned address.

| Event                         | Base                | Offset      | mcause        |
|-------------------------------|---------------------|-------------|---------------|
| Reset                         | `boot_addr_i[31:8]` | `0x80`      | —             |
| Illegal instruction           | `mtvec[31:8]`       | `0x84`      | `2`           |
| ECALL                         | `mtvec[31:8]`       | `0x88`      | `11`          |
| Load access fault             | `mtvec[31:8]`       | `0x8C`      | `5`           |
| Store access fault            | `mtvec[31:8]`       | `0x8C`      | `7`           |
| Interrupt `irq_id_i = n`      | `mtvec[31:8]`       | `n * 4`     | `0x8000_0000 + n` |

- Interrupt IDs 0..31 → offsets `0x00`..`0x7C`.
- Timer interrupt uses id 7 → offset `0x1C`, mcause `0x8000_0007`.
- Planned SoC encoding: MSI → 3 (`0x0C`), MTI → 7 (`0x1C`), MEI → 11 (`0x2C`).
- One vector slot = one 4-byte instruction, so put `j handler` in each slot.

### mtvec (CSR 0x305) — writable
- After reset, mtvec reads `{boot_addr_i[31:8], 8'h00}` until software writes it.
- `csrw mtvec, x` sets base = `x[31:8]`. Bits `[7:0]` always read 0 (MODE field reads 0, but interrupts are vectored as above).
- The reset vector always uses `boot_addr_i`, not mtvec.
- Typical SoC boot: reset at Boot ROM → copy image to IRAM → `csrw mtvec, 0x80000000`.

---

## 2. Core: CSR addresses

| CSR        | Address | Access | Notes                                               |
|------------|---------|--------|-----------------------------------------------------|
| mstatus    | `0x300` | RW     | only MIE (bit 3), MPIE (bit 7);
| mtvec      | `0x305` | RW     | 256-byte aligned base, see above                    |
| mepc       | `0x341` | RW     |                                                     |
| mcause     | `0x342` | RW     | bit 31 = interrupt, bits [4:0] = code               |
| mhartid    | `0xF14` | RO     | `{cluster_id_i[5:0], 1'b0, core_id_i[3:0]}`          |
| PCCRs      | `0x780`–`0x79E` | RW | PULP perf counters (N_PERF_CNT, default 2: cycles, instructions) |
| PCCR all   | `0x79F` | W      | write all counters                                  |
| PCER       | `0x7A0` | RW     | counter enable                                      |
| PCMR       | `0x7A1` | RW     | bit 0 = global enable, bit 1 = saturate; reset `0x3` |

Not present: mie, mip, mtval, mscratch, misa, mvendorid etc. (read as 0).

---

## 3. Machine timer (`peripherals/rv32i_timer.v`)

64 KB window, offsets are CLINT-compatible. Base address set by the SoC decoder.

| Register        | Offset   | Reset        |
|-----------------|----------|--------------|
| mtimecmp [31:0] | `0x4000` | `0xFFFF_FFFF` |
| mtimecmp [63:32]| `0x4004` | `0xFFFF_FFFF` |
| mtime [31:0]    | `0xBFF8` | `0`          |
| mtime [63:32]   | `0xBFFC` | `0`          |

- `irq = (mtime >= mtimecmp)`, level. Clear by writing a larger mtimecmp.
- mtime counts every `PRESCALE` clocks.
- Port: OBI-style slave (`req/gnt/rvalid`, `addr_i[15:2]`).

---

## 4. Planned SoC address map (from IIT-BBSR 1TOPS reference, AHB-Lite)

### AHB slaves

| Slave              | Base          | Size (reference) | Notes                         |
|--------------------|---------------|------------------|-------------------------------|
| Boot ROM           | `0x0000_1000` | 4 KB             | reset vector `0x0000_1080` with `boot_addr_i = 0x1000` |
| IRAM (instruction) | `0x8000_0000` | 32 KB            | size TBD (Sir: 16 KB)         |
| DRAM (data)        | `0x8001_0000` | 32 KB            | size TBD (Sir: 8 KB)          |
| Core debug         | `0x0B00_0000` | —                | depends on debug decision     |
| Accelerator        | `0x3000_0000` | —                |                               |
| AHB → APB bridge   | (APB range below) |              |                               |

### APB slaves

| Slave   | Base          | Notes                                   |
|---------|---------------|-----------------------------------------|
| CLINT   | `0x0200_0000` | mtimecmp `+0x4000`, mtime `+0xBFF8` (msip `+0x0000` if `clint_apb.sv` used) |
| PLIC    | `0x0C00_0000` | external interrupts → MEI               |
| UART    | `0x1000_0000` | debug console                           |
| SPI     | `0x1004_0000` | boot flash                              |
| GPIO    | `0x1006_0000` |                                         |
| SYSCTRL | `0x1008_0000` | not in our RTL yet                      |

### Boot flow (planned)
1. Reset → PC = `0x0000_1080` (Boot ROM).
2. Boot loader reads image from SPI flash, copies to IRAM / DRAM.
3. Boot loader writes `mtvec = 0x8000_0000`, jumps to IRAM.
4. Debugger reset → start in IRAM (`0x8000_0080`) — needs a `boot_addr_i` mux in the SoC.

### Memory size options

| Option        | IRAM  | DRAM  | Boot ROM |
|---------------|-------|-------|----------|
| Reference SoC | 32 KB | 32 KB | 4 KB     |
| Saroj Sir     | 16 KB | 8 KB  | 4 KB     |
| Old AXI SoC   | 64 KB | 64 KB | —        |

FreeRTOS: 16 KB + 8 KB comfortable, 8 KB + 4 KB minimum.

---

## 5. Notes for software

- Link code so vector slots sit at `base + 0x00 .. base + 0x8C`; `_start` usually after `0x90`.
- Data bus errors (`data_err_i`, AHB `HRESP=ERROR`) → load/store access fault. No instruction-side fault.
- FENCE = NOP, FENCE.I = jump to PC+4.
- Misaligned load/store is split into 2 bus accesses by the core (no trap).
