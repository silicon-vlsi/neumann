# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Verilog-2005 RV32I(C) RISC-V core (`rv32i_core`, derived from PULP **zero-riscy**; the PDFs in `Documentation/` are the original zero-riscy module docs) plus a small SoC wrapper with a UART debug bridge, a Python assembler/ISS toolchain, per-module SystemVerilog testbenches, and a Yosys→SKY130 synthesis flow. The README files cover usage, the memory map, the UART debug protocol, and the test program conventions in detail.

## Commands

Run all of these from the **repo root**. The testbenches load `sw/hex/*.hex` with `$readmemh` using paths relative to the current directory, and `sim/run.do` refuses to run from anywhere else.

```bash
# Full flow: assemble sw/asm/*.s → sw/hex/, ISS golden-model check, RTL sim (auto-detects iverilog, then vsim)
python scripts/run_all.py
python scripts/run_all.py --sim iverilog|questa|skip
python scripts/run_all.py --test sort          # single program (RTL sim only if tb/tb_<name>.v exists)
python scripts/run_all.py --skip-asm --skip-iss

# Individual steps
python scripts/assemble.py [name ...]          # uses sw/rv32i_asm.py
python scripts/iss_verify.py [name ...] --verbose
python sw/iss.py sw/hex/<name>.hex --all --signed   # also -r regs, -d addr[:count], -s addr[:count], -n limit

# QuestaSim directly (compiles sim/core.f + tb/tb_sort.v + tb/tb_fib.v)
vsim -c -do sim/run.do
```

**Unit-level SV verification (QuestaSim only):** `verify/run_verification.py`. Its docstring still refers to the folder as `1TOPS_VERIFICATION`; that folder is now `verify/`.
```bash
cd verify
python run_verification.py --list
python run_verification.py alu                 # or decoder, lsu, if_stage, id_stage ... ; aliases like rf, csr, ctrl
python run_verification.py all --clean
python run_verification.py lsu --trans 5000 --seed 42 --cov
```
The build output goes to `verify/<component>/sim/`. The exit code is 0 only if every component that ran passed.

**Synthesis:** `bash synth/run_synth.sh` runs Yosys with `synth/rv32i_core_sky130.ys`. It fetches the sky130 HD liberty from `$PDK_ROOT` or downloads it. The reports go to `synth/reports/`, and `Synthesis.md` summarises the results.

## Architecture notes

- **The RTL source list is `sim/core.f`.** Both the iverilog path in `run_all.py` and `sim/run.do` read it. The synthesis script has its own hardcoded file list in `synth/rv32i_core_sky130.ys`. If you add or rename an RTL file, update both. The include directory `rtl/core` is required for `rv32i_defines.vh`.
- **Hierarchy:** `top_soc` (`rtl/soc/`) wraps `rv32i_core` and `uart_debug_unit`, and arbitrates the data bus between the core's LSU and the UART debug master. `rv32i_core` contains `rv32i_if_stage` (prefetch buffer → fetch FIFO → compressed decoder), `rv32i_id_stage` (decoder, controller, register file, int controller, imm gen), `rv32i_ex_block` (ALU), the LSU, the CSRs and the debug unit. Instruction and data memory buses use an OBI-style req/gnt/rvalid handshake. The memories in `rtl/mem/` are simulation models only.
- **Clock gating:** `rtl/soc/cluster_clock_gating.v` is the live ICG cell, and the core depends on it, so synthesis also pulls it in from `rtl/soc/`.
- **Three verification tiers:** (1) `sw/iss.py` is the golden reference model; `scripts/iss_verify.py` holds per-program expected data in its `EXPECTED` dict. (2) Full-core RTL testbenches in `tb/` print `RESULT: ALL N CHECKS PASSED`, `... FAILED` or `TIMEOUT:`, and `run_all.py` parses those exact strings, so keep the format if you write a new testbench. (3) Per-module class-based SV testbenches in `verify/<component>/` (generator/driver/monitor/scoreboard/coverage plus bound SVA). `run_verification.py` has a `COMPONENTS` dict with each one's file list, top module, transaction plusarg and pass message.
- **`verify/` uses its own copies of the RTL** (`verify/*/RTL/*.v`, `verify/ALU/rv32i_Alu.v`, `verify/LSU/...`). These are stale snapshots, and most already differ from `rtl/core/` (for example, the decoder case widths). A passing unit test does not prove that the current `rtl/core` file is correct. When you change core RTL, either sync the copy or tell the user it differs.
- **Test program ABI** (each `sw/asm/*.s`): boot at `0x80`, followed by a vector table of `j` instructions at `0x84` (illegal), `0x88` (ecall) and `0x8C` (LSU error). On success the program writes `0xC0DE0001` to address `0x000`. A trap writes a `0xBAD0000x` marker to `0x004`. The ISS check and the testbenches both depend on this. `rv32i_compliance.s` is the main ISA coverage test.
- The assembler (`sw/rv32i_asm.py`) is a custom two-pass assembler that supports only base RV32I plus the `li`, `nop` and `j` pseudo-ops, not the full GNU syntax. Commit regenerated `sw/hex/*.hex` files together with their `.s` source.
