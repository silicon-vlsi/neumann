# neumann — RISC-V microcontroller SoC

Low-area, low-power RISC-V microcontroller SoC for the 1TOPS project. Target: GF 28nm.
It combines the **neumann** core (RV32IC + Zicsr, 2-stage pipeline, zero-riscy derived) with an
**AHB-Lite + APB uncore** (memories and peripherals). Our own OBI→AHB bridges and a 3-master
bus unit join the two.

Top module: `neumann_soc` (`rtl/top/neumann_soc.sv`). File list: `neumann_soc.f`.

```
  host PC --UART--> uart_debug_unit --debug_*--> core debug port (halt / step / regs / CSRs)
                         | mem_* (RMEM / WMEM)
                         v
  rv32i_core --instr--> obi2ahb_i --- IFU (m0) --+
             --data---> obi2ahb_d --- LSU (m1) --+--> ebu3 --AHB-Lite--> uncore
  uart_debug_unit ----> obi2ahb_d --- DBG (m2) --+   DBG > LSU > IFU       |
                                                                           +-- adrdecs (address decoder)
  irq_enc <-- MTimerInt, MSwInt (CLINT), MExtInt (PLIC)                    +-- Boot ROM 4 KB   0x0000_1000
     +--> core irq_i / irq_id_i (MEI 11, MSI 3, MTI 7)                     +-- IRAM 16 KB      0x8000_0000
                                                                           +-- EXT slot: DRAM 8 KB 0x8001_0000
  rst_ni --> rst_sync --> everything                                       +-- AHB->APB: CLINT PLIC UART
                                                                                 GPIO SPI SDC
```

## Features

- **Core:** RV32I + C (compressed) + Zicsr, 2-stage pipeline, machine mode, vectored interrupts, and a debug unit with halt, resume, step and register/CSR access
- **Low power:** latch-based clock gating of the core clock and of each register-file register (`CLK_GATING`)
- **Bus:** AHB-Lite with 3 masters (instruction fetch, load/store, debug) and fixed priority. AHB→APB bridge for the peripherals
- **Memories:** 4 KB boot ROM, 16 KB IRAM, 8 KB DRAM
- **Peripherals:** CLINT (timer + software interrupt), PLIC, 16550 UART, 32-bit GPIO with interrupts, 2 SPI masters (SPI, SDC)
- **Debug:** a UART debug link works while the core runs. It can load programs, read and write memory, and halt, step and inspect the core
- **Boot:** a boot ROM with 3 modes selected by pins: SPI flash on the SDC port, direct, or debug UART
- **Bus errors:** unmapped addresses and wrong access sizes get an AHB ERROR response, which becomes a load/store access-fault trap

---

## 1. Repository layout

```
neumann/
├── README.md            this file
├── neumann_soc.f        file list (paths relative to the repo root), top = neumann_soc
├── rtl/
│   ├── top/             neumann_soc.sv                      SoC top level
│   ├── bus/             ebu3.sv, obi2ahb_i.v, obi2ahb_d.v   bus unit + OBI->AHB bridges
│   ├── sys/             irq_enc.v, rst_sync.v               interrupt encoder, reset synchroniser
│   ├── core/            rv32i_*.v, cluster_clock_gating.sv, rv32i_defines.vh   neumann core
│   └── debug/           uart_debug_unit.v, uart_rx.v, uart_tx.v              UART debug unit
├── config/config.vh     SoC configuration: memory map, which peripherals exist
├── uncore_ip/           uncore IP: AHB/APB uncore, peripherals, generic cells
├── sw/
│   ├── boot/            rom.S, link_rom.ld, rom.hex (built boot ROM image)
│   ├── app/             start.S, link_app.ld, soc.h   template for programs that run on the SoC
│   └── bin2hex.py       binary -> one 32-bit word per line, for $readmemh
├── Documentation/       zero-riscy module documents, SoC diagram
├── verify/              per-module SystemVerilog testbenches (core units)
└── rtlGuidelines.md     RTL coding guidelines
```

---

## 2. RTL

### rtl/top

| File | What it is |
|---|---|
| `neumann_soc.sv` | **Top.** Instantiates `rst_sync`, `rv32i_core`, `uart_debug_unit`, the 3 bridges, `ebu3`, the `uncore`, the DRAM (`ram_ahb` on the uncore EXT slot) and `irq_enc`. It includes `config.vh` and `parameter-defs.vh` to build the configuration struct `P`. |

Parameters:

| Parameter | Default | Meaning |
|---|---|---|
| `CLK_GATING` | 1 | 1 = latch clock gates in the core (register file + core clock). 0 = no gates (FPGA) |
| `DBG_CLKS_PER_BIT` | 868 | UART debug baud = clk / this (868 → 115200 at 100 MHz) |
| `BOOT_ADDR` | `0x0000_1000` | core boot address; first fetch at `BOOT_ADDR + 0x80` |
| `IRAM_PHYS_RANGE` | `0x3FFF` | IRAM size − 1 (16 KB) |
| `DRAM_PHYS_RANGE` | `0x1FFF` | DRAM size − 1 (8 KB) |

Ports:

| Port | Dir | Meaning |
|---|---|---|
| `clk_i`, `rst_ni` | in | clock; active-low reset (asynchronous assert, synchronised release inside) |
| `test_en_i` | in | DFT: forces the clock gates open and bypasses the reset synchroniser. 0 in normal use |
| `fetch_enable_i` | in | 1 = core starts fetching after reset |
| `dbg_rx_i`, `dbg_tx_o` | in/out | UART debug link (8N1) |
| `dbg_halted_o` | out | 1 while the debug unit has the core halted |
| `uart_rx_i`, `uart_tx_o` | in/out | application UART (16550) |
| `gpio_i[31:0]`, `gpio_o[31:0]`, `gpio_oe_o[31:0]` | in/out | GPIO; **`gpio_i[31:30]` are the boot-mode pins** (section 4) |
| `spi_miso_i`, `spi_mosi_o`, `spi_cs_o[3:0]`, `spi_sck_o` | in/out | SPI master |
| `sdc_miso_i`, `sdc_mosi_o`, `sdc_cs_o[3:0]`, `sdc_sck_o` | in/out | 2nd SPI master (SDC port): **boot flash on CS0** (section 4) |

### rtl/bus

| File | What it is |
|---|---|
| `ebu3.sv` | 3-master External Bus Unit. Masters: IFU m0 (lowest), LSU m1, DBG m2 (highest). It uses AHB `HBUSREQ`/`HGRANT` with fixed priority DBG > LSU > IFU. Only the granted master drives `HTRANS != IDLE`, and the output mux puts its address phase on the bus. `HMASTER` (registered) is the data-phase owner and selects `HWDATA`/`HWSTRB`. `HPROT[0]` marks a data access. |
| `obi2ahb_i.v` | Bridge from the core instruction port (OBI-style req/gnt/rvalid) to AHB master m0. Word reads only. `HTRANS` is driven only when `req & ~hold_i & HREADY`. |
| `obi2ahb_d.v` | Bridge from a data port to an AHB master, used twice: core LSU (m1) and debug unit (m2). It turns byte enables into `HSIZE` + `HADDR[1:0]` and copies byte/half store data to all lanes. `HWDATA`/`HWSTRB` are registered at `gnt`. `HRESP` drives `data_err_o`, which raises a load/store access fault. |

### rtl/sys

| File | What it is |
|---|---|
| `irq_enc.v` | Priority encoder into core `irq_i` / `irq_id_i`: MEI (PLIC) → id 11, then MSI (CLINT msip) → id 3, then MTI (CLINT timer) → id 7. The core vectors to `mtvec + 4*id`. |
| `rst_sync.v` | 2-flop reset synchroniser with `test_mode_i` bypass. |

### rtl/core — neumann core

| File | What it is |
|---|---|
| `rv32i_core.v` | Core top. Parameters `N_PERF_CNT`, `CLK_GATING`. |
| `rv32i_if_stage.v`, `rv32i_prefetch_buffer.v`, `rv32i_fetch_fifo.v` | Fetch. The PC mux covers boot, jump, branch, trap/irq vector and debug. Also the instruction-bus FSM, and a FIFO that aligns 16-bit and misaligned 32-bit instructions. |
| `rv32i_compressed_decoder.v` | Expands RVC instructions to 32-bit. RVC HINTs execute as no-ops. |
| `rv32i_id_stage.v`, `rv32i_decoder.v`, `rv32i_controller.v` | Decode, register-file access and hazards. The decoder treats FENCE as a NOP and FENCE.I as a jump to PC+4. The main control FSM handles boot, stalls, exceptions, interrupts and debug. |
| `rv32i_ex_block.v`, `rv32i_alu.v` | ALU. |
| `rv32i_load_store_unit.v` | Data-bus FSM: byte enables, misaligned split, sign extension, bus error → access fault. |
| `rv32i_cs_registers.v` | CSRs: mstatus (MIE/MPIE), mtvec (writable, 256-B aligned), mepc, mcause, mhartid, performance counters. |
| `rv32i_int_controller.v` | Accepts interrupts when `mstatus.MIE` = 1. |
| `rv32i_debug_unit.v` | Core debug port: halt, resume, step, GPR / CSR / NPC / PPC access. |
| `rv32i_register_file.v` | 31 × 32 registers. With `CLK_GATING` = 1, each register has its own clock gate, so only the written register gets a clock edge. |
| `cluster_clock_gating.sv` | Latch-based clock gate (ICG structure). A latch that is transparent while `clk_i` is low holds `en_i \| test_en_i`, which is ANDed with `clk_i`. For implementation it maps to the library ICG cell (same ports). |
| `rv32i_defines.vh` | Opcode / ALU / CSR constants. |

Trap vectors are offsets from `mtvec`, which equals `BOOT_ADDR` until software writes it:

| Event | Offset |
|---|---|
| reset | `+0x80` |
| illegal instruction | `+0x84` |
| ecall | `+0x88` |
| load/store access fault | `+0x8C` |
| interrupt id n | `+4n` |

### rtl/debug — UART debug unit

| File | What it is |
|---|---|
| `uart_debug_unit.v` | Takes byte commands on the debug UART and replies `0x90` = ACK. Multi-byte values are LSB first. Register, CSR and PC commands need the core halted. Memory commands go over the bus (ebu3 master 2) and also work while the core runs. |
| `uart_rx.v`, `uart_tx.v` | 8N1 UART with a `CLKS_PER_BIT` parameter. |

Debug commands:

| Bytes | Command |
|---|---|
| `01` | HALT |
| `02` | RESUME |
| `03` | STEP |
| `04` | STATUS |
| `10 n` | read GPR n |
| `11 n d4` | write GPR n |
| `20 a2` | read CSR |
| `21 a2 d4` | write CSR |
| `30` | read NPC + PPC |
| `40 a4` | read memory word |
| `41 a4 d4` | write memory word |

### config/config.vh — memory map

| Region | Base | Notes |
|---|---|---|
| Boot ROM | `0x0000_1000` | 4 KB |
| SDC (2nd SPI) | `0x0001_3000` | word access |
| CLINT | `0x0200_0000` | msip `+0`, mtimecmp `+0x4000`, mtime `+0xBFF8` (counts every clock) |
| PLIC | `0x0C00_0000` | sources: GPIO 3, SPI 6, SDC 9, UART 10. Word access |
| UART (16550) | `0x1000_0000` | byte access |
| SPI | `0x1004_0000` | word access |
| GPIO | `0x1006_0000` | word access |
| IRAM | `0x8000_0000` | 64 KB window, 16 KB physical |
| DRAM (EXT slot) | `0x8001_0000` | 64 KB window, 8 KB physical |

Every window must be a `2^n − 1` mask with an aligned base. An access to an unmapped address, or with the wrong size for the target, gets an AHB ERROR response. That becomes a load access fault (mcause 5) or a store access fault (mcause 7).

### uncore_ip/

Open-source AHB/APB uncore IP. License: Apache-2.0 WITH SHL-2.1. Origin and commit are in `uncore_ip/VERSION.txt`; see `uncore_ip/LICENSE`. Our changes are marked `neumann` in `src/uncore/uncore.sv`.

| File(s) | Role |
|---|---|
| `src/cvw.sv`, `config/shared/*.vh` | config package `cvw_t` and the code that fills `P` from `config.vh` |
| `src/uncore/uncore.sv` | uncore top: decoder, ROM, RAM, AHB→APB bridge, peripherals, response mux, EXT slot, default (error) slave |
| `src/mmu/adrdecs.sv`, `adrdec.sv` | address decoder, including the access-size check |
| `src/uncore/rom_ahb.sv`, `ram_ahb.sv` | ROM / RAM AHB slaves. The RAM has byte strobes |
| `src/uncore/ahbapbbridge.sv` | AHB → APB bridge |
| `src/uncore/clint_apb.sv`, `plic_apb.sv` | timer + software interrupt; interrupt controller |
| `src/uncore/uart_apb.sv`, `uartPC16550D.sv` | 16550 UART |
| `src/uncore/gpio_apb.sv` | 32-bit GPIO with edge/level interrupts |
| `src/uncore/spi_apb.sv`, `spi_controller.sv`, `spi_fifo.sv` | SPI master (2 instances: SPI and SDC) |
| `src/uncore/pwm_apb.sv` | PWM (disabled in config) |
| `src/generic/...` | flops, mux, `ram1p1rwbe` (RAM array), `rom1p1r` (ROM array) |

---

## 3. Memories in simulation

The memories are behavioural arrays. Hierarchical paths from the `neumann_soc` instance (`dut`):

| Memory | Array | Word index |
|---|---|---|
| Boot ROM | `dut.u_uncore.bootrom.bootrom.memory.ROM` | `(addr - 0x0000_1000) >> 2` |
| IRAM | `dut.u_uncore.ram.ram.memory.ram.RAM` | `(addr - 0x8000_0000) >> 2` |
| DRAM | `dut.u_dram.memory.ram.RAM` | `(addr - 0x8001_0000) >> 2` |

`sw/boot/rom.hex` has one 32-bit word per line; word 0 is address `0x0000_1000`. Load it into the ROM array at time 0:
```systemverilog
$readmemh("sw/boot/rom.hex", dut.u_uncore.bootrom.bootrom.memory.ROM);
```
Under Verilator, `rom1p1r` calls a DPI function `getenvval`, so a Verilator build needs a small C++ stub:
```cpp
#include <cstdlib>
extern "C" const char* getenvval(const char* n) { const char* v = std::getenv(n); return v ? v : ""; }
```

---

## 4. Boot flow (`sw/boot/rom.S`)

1. Reset → PC = `0x0000_1080`.
2. The ROM sets `mtvec = 0x8000_0000` and `sp = 0x8001_2000`, enables GPIO inputs 31:30, and reads the boot pins:

| `gpio_i[31:30]` | Mode | What the ROM does |
|---|---|---|
| `00` | SDC flash boot | copies the image from the SPI flash on the SDC port into IRAM/DRAM and jumps to its entry |
| `01` | direct boot | jumps to `0x8000_0080` (image already in IRAM/DRAM) |
| `1x` | debug boot | writes 0 to the mailbox `0x8001_0004`, polls it, and jumps to the address written there |

### SDC flash boot

The flash is a W25Qxx-type SPI flash, SPI mode 0. Connections:

| Flash pin | SoC pin |
|---|---|
| SCK | `sdc_sck_o` |
| DI | `sdc_mosi_o` |
| DO | `sdc_miso_i` |
| CS | `sdc_cs_o[0]` |

SCK = clk / 4. The ROM sends `0xAB` (release from power-down) and waits at least 3 µs. It then sends `0x03 00 00 00` (read from address 0) and streams the whole image in one CS frame.

Flash image (all words little-endian):

| Flash address | Content |
|---|---|
| `0x00` | header, 8 words: magic `0x4D55454E` ("NEUM"), `iram_len`, `dram_len`, `entry`, `checksum`, 0, 0, 0 |
| `0x20` | IRAM image, `iram_len` bytes → `0x8000_0000` |
| `0x20 + iram_len` | DRAM image (`.data`), `dram_len` bytes → `0x8001_0040` |

Image rules:
- `checksum` is the 32-bit sum of all image words.
- Both lengths must be multiples of 4.
- `iram_len` ≤ 16 KB, and `dram_len` ≤ 8 KB − 64.

The ROM writes `BOOT_STATUS` at `0x8001_000C`:

| Value | Meaning |
|---|---|
| `0xB0070000` | loading |
| `0xB00700AA` | ok (then jumps to `entry`) |
| `0xB00700E1` | bad magic |
| `0xB00700E2` | bad length |
| `0xB00700E3` | bad checksum |

On any error code the ROM releases CS and falls back to debug boot.

### Debug boot

Load the program over the debug UART with `41` (write memory word). Then write its entry address (e.g. `0x8000_0080`) to `0x8001_0004`, and the ROM jumps there.

Example: to write `0x00000297` to `0x8000_0080`, send `41 80 00 00 80 97 02 00 00`. The reply is `90`.

---

## 5. Software (`sw/`)

| File | What it is |
|---|---|
| `boot/rom.S` + `boot/link_rom.ld` | boot ROM source (section 4); `boot/rom.hex` is the built image |
| `app/start.S` | IRAM program start: vector table at `0x8000_0000` (32 interrupt slots, then entry `+0x80`, illegal `+0x84`, ecall `+0x88`, fault `+0x8C`). `_start` sets up the stack, clears .bss, calls `main` and writes its return value to `0x8001_0000`. The trap entry saves registers and calls `c_trap(mcause, mepc)`, which returns the new mepc |
| `app/link_app.ld` | code in IRAM; data/bss in DRAM from `0x8001_0040` (the first 64 bytes hold the status word `+0`, boot mailbox `+4`, step `+8` and boot status `+0xC`); stack top `0x8001_2000` |
| `app/soc.h` | addresses and register macros for all peripherals |
| `bin2hex.py` | `python3 bin2hex.py in.bin out.hex` |

Build a program (RV32IC):
```bash
riscv64-unknown-elf-gcc -march=rv32ic_zicsr -mabi=ilp32 -O2 -ffreestanding -nostdlib \
    -T sw/app/link_app.ld sw/app/start.S my.c -o my.elf
riscv64-unknown-elf-objcopy -O binary --only-section=.vectors --only-section=.text my.elf iram.bin
riscv64-unknown-elf-objcopy -O binary --only-section=.data my.elf dram.bin
python3 sw/bin2hex.py iram.bin iram.hex      # load at 0x8000_0000
python3 sw/bin2hex.py dram.bin dram.hex      # load at 0x8001_0040 (word index 16 of DRAM)
```
Rebuild the boot ROM:
```bash
riscv64-unknown-elf-gcc -march=rv32ic_zicsr -mabi=ilp32 -nostdlib -T sw/boot/link_rom.ld sw/boot/rom.S -o rom.elf
riscv64-unknown-elf-objcopy -O binary rom.elf rom.bin && python3 sw/bin2hex.py rom.bin sw/boot/rom.hex
```

---

## 6. Compile

Run from the repo root.

Questa:
```bash
vlib work
vlog -sv -f neumann_soc.f your_tb.sv
vsim -c your_tb -do "run -all; quit"
```
Verilator (5.x):
```bash
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-MULTIDRIVEN \
  --top-module your_tb -f neumann_soc.f your_tb.sv getenv_stub.cpp
```

A testbench needs:
- a clock, and `rst_ni` held low for a few cycles;
- `fetch_enable_i = 1` and `test_en_i = 0`;
- `gpio_i[31:30]` set for the boot mode;
- the ROM image (section 3), plus IRAM/DRAM images or a debug-UART driver.

The application UART is a 16550; the program sets the baud divisor (baud = clk / (16 × divisor)). The program's result word is at `0x8001_0000`.

---

## 7. Verification

The SoC passes these regressions in Questa, with `CLK_GATING` both 1 and 0:

| Suite | Content |
|---|---|
| riscv-arch-test | RV32I, C and Zicsr compliance subset (65 tests) |
| Random instructions | 100 random programs, register and memory state checked against the Spike ISS |
| Boot | SDC flash boot (good and corrupted images), direct boot, debug-UART boot |
| Peripherals & interrupts | CLINT timer/software interrupts, PLIC, all 32 GPIO pins, UART, SPI/SDC, exceptions, FreeRTOS soak test |
| Bus | 3-master arbitration with debug traffic, unmapped and wrong-size accesses (ERROR response → trap) |
