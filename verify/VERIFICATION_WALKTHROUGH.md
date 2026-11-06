# 1TOPS Verification Walkthrough

How every module of the RV32I core is verified on its own, and how to run any of them
in QuestaSim from one script: `run_verification.py`.

---

## 1. How each component is verified

Every block has its own class-based, layered SystemVerilog testbench. They all follow
the same flow:

```
Generator --mailbox--> Driver --> interface --> DUT
                                      |
                                   Monitor --+--> Scoreboard  (reference model, pass/fail)
                                             +--> Coverage    (covergroups)
                    Assertions (SVA) bound into the DUT
```

| Layer        | Job |
|--------------|-----|
| Transaction  | One packet of DUT inputs/outputs with `rand` fields and constraints |
| Generator    | Directed scenarios first, then N randomized transactions, into a mailbox |
| Driver       | Takes transactions from the mailbox and drives the interface pins (clocking block, posedge + 1) |
| Interface    | All DUT pins, `drv_cb` / `mon_cb` clocking blocks and modports |
| Monitor      | Samples the pins at negedge and sends what it saw to scoreboard and coverage |
| Scoreboard   | Reference model in SV, predicts the expected output, compares, counts pass/fail |
| Coverage     | Covergroups on opcodes / select lines / FSM states / handshakes and crosses |
| Assertions   | SVA properties `bind`-ed into the DUT, no RTL edit needed |
| Environment  | Builds all of the above, wires the mailboxes, runs and reports |
| tb_top       | Clock, interface, DUT instance, reads `+NUMTXN`, starts the env |

### Per component

| Component | Folder | Top | What gets checked |
|-----------|--------|-----|-------------------|
| ALU | `ALU/` | `alu_top` | All 22 opcodes with random + corner operands; result, adder, comparison, equal flags |
| Imm_gen | `Imm_gen/` | `tb_top` | Every `imm_sel` (I, S, SB, U, UJ, PCINCR) and sign extension |
| Decoder | `rv32i_decoder/` | `Decoder_tb_top` | Full decode reference model: ALU op, mux selects, regfile WE, CSR, load/store, jump/branch, illegal/ecall/ebreak/mret |
| Int controller | `int_controller/` | `Controller_tb_top` | IDLE -> IRQ_PENDING -> IRQ_DONE FSM, enable, ack/kill, irq id |
| LSU | `LSU/` | `lsu_top` | Size x offset x we x sign-ext sweep + random against a memory slave; mirror memory checks load data and byte enables |
| Register file | `rv32i_register_file/` | `Reg_tb_top` | 8 tests (random, write, read, write_read, x0, corner, same_addr, test_en); mirror model of both read ports, x0 hard-wired, DFT `test_en_i` (all clock gates open), reset clearing the write-data flop |
| EX block | `rv32i_ex_block/` | `Ex_tb_top` | ALU through the EX wrapper: wdata, adder / jump target, branch decision, `ex_ready_o` vs LSU; directed sweep of all 22 ops x 13 corner operands, equal / off-by-one pairs, every shift amount |
| Compressed decoder | `rv32i_compressed_decoder/` | `Cdec_tb_top` | **Every one of the 49152 16-bit compressed encodings**, plus random 32-bit; expander written from the RVC spec (immediates decoded, then re-encoded to I/S/B/J/U/R), illegal flag, is_compressed |
| Fetch FIFO | `rv32i_fetch_fifo/` | `Fifo_tb_top` | Instruction stream model: rebuilds halfwords from the pushed words, follows the PC over aligned / unaligned and 16 / 32-bit instructions, checks `out_valid`, `out_addr`, instruction bits and `in_ready` every cycle; clears to unaligned targets |
| Prefetch buffer | `rv32i_prefetch_buffer/` | `Pref_tb_top` | Driver is also an instruction memory (random grant, 1-4 cycle rvalid latency); every delivered instruction is checked against memory at the expected PC, across branches during outstanding fetches (WAIT_ABORTED drops the stale data) |
| CS registers | `rv32i_cs_registers/` | `Csr_tb_top` | mstatus / mtvec / mepc / mcause / mhartid, csrrw/s/c, exception entry (save_if / save_id) and mret, all 11 perf counters with enable, saturation and the 0x79F "write all" |
| Debug unit | `rv32i_debug_unit/` | `Dbg_tb_top` | Driver is a debug-bus master (holds req until gnt, CSR writes take 2 cycles). Cycle model of every output: gnt / rvalid / rdata, halt request -> ack -> halted -> resume, GPR / CSR access only while halted, NPC jump, single-step trap and hit flag |
| Controller | `rv32i_controller/` | `Ctrl_tb_top` | Cycle model of the whole FSM (12 reachable states) and every output; directed boot, branch / jump, IRQ, all 6 flush causes, WFI sleep and wake, debug from decode and from sleep |
| IF stage | `rv32i_if_stage/` | `If_tb_top` | Prefetcher + compressed decoder + IF/ID register: each `if_valid` must carry the expected PC, IF/ID must get the decompressed instruction next cycle; every `pc_set` target (boot / jump / exception ILL/ECALL/IRQ vector / ERET / DBG_NPC) |
| ID stage | `rv32i_id_stage/` | `Id_tb_top` | Driver plays the IF and EX side. Scoreboard reuses the decoder reference model, then checks ALU operands (register / PC / immediates / misaligned forward), store data, the load / branch / jump stall FSM, register writeback (EX / LSU / CSR data, debug write) with a mirror register file read back through the debug port, and branch / jump redirects |

All new blocks use the `RTL/` + `SV_tb/` layout of the decoder and int_controller,
compile with `-mfcu` (the bind sits in the assertions file), take `+NUMTXN=` and print
`[SCB] TEST PASSED` / `[SCB] TEST FAILED`. When a scoreboard sees a mismatch on
something it can read back (CSR value, FSM state) it reports it once and re-syncs, so
one bug does not turn into thousands of errors.

---

## 2. The master script: `run_verification.py`

It sits in `1TOPS_VERIFICATION/`. It knows every component's file list, compile order,
include folders, top module, transaction knob and pass message, so you only give it
a name.

What it does for each component:

1. Checks that `vlib`, `vlog`, `vsim` (and `vcover` with `--cov`) are on `PATH`
2. Creates `<component>/sim/` and the `work` library in it
3. `vlog` compile, log in `sim/compile.log`
4. `vsim -c` batch run, log in `sim/sim.log`
5. With `--cov`: saves `<name>.ucdb`, writes `sim/coverage.txt` and the HTML report
   in `sim/covhtmlreport/index.html`
6. Decides PASS / FAIL: the scoreboard's pass message has to be there, and there
   can be no `** Error`, no `** Fatal` and no global timeout
7. Prints a summary table and saves it in `regression_summary.txt`

The exit code is 0 only if everything that ran passed, so you can use it in CI too.

### Setup (Windows)

Add the QuestaSim binary folder to `PATH`, e.g. `C:\questasim64_2024.1\win64`.
Check with `vsim -version`, then open a terminal in `1TOPS\1TOPS_VERIFICATION`.

### Commands

```
python run_verification.py --list                 # all 15 components and if they are ready
python run_verification.py alu                    # one component
python run_verification.py csr dbg ctrl           # a few (short names work)
python run_verification.py all                    # full regression (same as no name)
```

| Flag | What it does |
|------|--------------|
| `--trans N` | Number of transactions (clock cycles for the sequential blocks). Directed scenarios always run on top |
| `--seed N` | Fixed `-sv_seed`. Default `random`; the seed used is printed in the summary so a failing run can be repeated |
| `--cov` | Code coverage (`-cover bcesft`) + functional coverage, text and HTML report |
| `--gui` | Opens the Questa GUI with all waves added (one component at a time) |
| `--clean` | Deletes `<component>/sim/` before running |
| `--vsim-args "..."` | Anything extra straight to `vsim`, e.g. `+TEST=x0` for the register file or `+NOSWEEP` for the compressed decoder |
| `-v` | Print the full simulation log instead of the short summary lines |

Short names: `imm`, `dec`, `intc`, `rf`, `ex`, `cdec` / `rvc`, `fifo`, `pref`, `csr`,
`dbg`, `ctrl`, `if`, `id`.

### Examples

```
python run_verification.py all --cov                          # regression with coverage
python run_verification.py alu --trans 1000 --seed 7          # 1000 per opcode, seed 7
python run_verification.py rf --vsim-args="+TEST=test_en"     # one register file test
python run_verification.py lsu --vsim-args="-GGNT_DELAY=3 -GRVALID_DELAY=2"
python run_verification.py id --gui                           # debug in waves
python run_verification.py all --clean --cov --trans 5000
```

### Per-component scripts

Every block also has its own script (same flags, run it from the block's folder):

| Component | Script |
|-----------|--------|
| ALU | `ALU/run.py` |
| Imm_gen | `Imm_gen/scripts/run_imm_gen.py` |
| LSU | `LSU/scripts/run_sim.py` (`--gnt`, `--rvalid` latency knobs) |
| Decoder, int_controller | `<folder>/scripts/run_sim.py` |
| All `rv32i_*` blocks | `<folder>/scripts/run_sim.py` (`--trans`, `--seed`, `--cov`, `--gui`, `--clean`, `-v`; register file also `--test`, compressed decoder also `--nosweep`) |

---

## 3. RTL bugs the new testbenches found (fixed)

These three bugs were found by the new testbenches and are now fixed in
`RV32I_zeroriscy/rtl/core/` and in the testbench `RTL/` copies.

| # | Block | Bug | Fix |
|---|-------|-----|-----|
| 1 | `rv32i_compressed_decoder.v` | `c.jr x0` (`0x8002`) is a reserved encoding and must be illegal, but it was expanded to `jalr x0, 0(x0)` with `illegal_instr_o = 0` | In the `c.jr` branch: `if (instr_i[11:7] == 5'b0) illegal_instr_o = 1'b1;` |
| 2 | `rv32i_cs_registers.v` | `csrrc` on PCER (0x7A0), PCMR (0x7A1) and the counters (0x780-0x79F) computed `wdata & ~q` instead of `q & ~wdata` (clearing bit 0 of PCER = 0x7FF gave 0x000, not 0x7FE) | `PCCR_q[pi] & ~csr_wdata_i`, `PCMR_q & ~csr_wdata_i[1:0]`, `PCER_q & ~csr_wdata_i[N_PERF_COUNTERS-1:0]` |
| 3 | `rv32i_cs_registers.v` | Reading 0x78B-0x79F indexed `PCCR_q[]` past its 11 entries, so `csr_rdata_o` was X | `perf_rdata = (csr_addr_i[4:0] < N_PERF_REGS) ? PCCR_q[csr_addr_i[4:0]] : 32'b0;` |

Two design contracts are written down as assertions rather than bugs: the prefetch
buffer loses the branch target if `branch_i` comes without `req_i`, and the IF stage
hands the same instruction to ID twice if `req_i` is low with no `halt_if_i`. The
controller never does either, so the testbenches keep to that and the assertions
(`a_branch_needs_req`, `a_req_low_halts`) catch anyone who does not.

---

## 4. How the testbenches themselves were checked

QuestaSim is not available in the cloud machine these were written on, so every
testbench was run on Verilator 5.020 through a translation layer. It converted the
clocking blocks, dropped the covergroups and dropped the `randomize() with` blocks,
which that Verilator does not support. The same files then go to Questa unchanged.

- Every scoreboard was run against the real RTL (results below) and against your
  decoder and int_controller testbenches as a sanity check of the flow (both pass).
- **Mutation testing:** for every block, bugs were injected into a copy of the RTL and
  the testbench had to fail. All 37 caught (the one register-file mutant that
  survived turned out to be logically equivalent and was replaced).
- Verilator ignores constraints, so the random phases there were fully unconstrained,
  which is harsher on the reference models than Questa will be.

| Block | Cycles / transactions | Result | Mutants caught |
|-------|----------------------|-----------------------|----------------|
| register_file | 8253 (reset toggling half the time) | PASS | 3 / 3 |
| ex_block | 10674 | PASS | 3 / 3 |
| compressed_decoder | 54152 | PASS (after fix 1) | 3 / 3 |
| fetch_fifo | 20664 | PASS | 4 / 4 |
| prefetch_buffer | 30749 | PASS | 3 / 3 |
| cs_registers | 20436 | PASS (after fixes 2, 3) | 4 / 4 |
| debug_unit | 20186 | PASS | 4 / 4 |
| controller | 20383 | PASS | 4 / 4 |
| if_stage | 20407 | PASS | 4 / 4 |
| id_stage | 20846 | PASS | 5 / 5 |

What has **not** run yet: the covergroups and the constraint solver (only Questa
has them), so the first `--cov` run in Questa is the first time those compile. They
follow the same patterns as your decoder / int_controller coverage files. The
crosses only contain combinations the hardware can actually produce, so 100%
functional coverage is reachable, but some bins may need more `--trans` to close.

---

## 5. Adding a new component

Add one entry to `COMPONENTS` in `run_verification.py`:

```python
"my_block": dict(
    dir="rv32i_my_block",
    sources=["RTL/rv32i_my_block.v", "SV_tb/My_interface.sv", "SV_tb/My_Assertions.sv", "SV_tb/My_tb_top.sv"],
    incdirs=["SV_tb", "RTL"],
    top="My_tb_top",
    mfcu=True,
    trans="+NUMTXN={n}",
    default_trans=1000,
    passmsg="TEST PASSED",
),
```

Read `+NUMTXN` in the tb_top with `$value$plusargs` like the other blocks do, and print
`[SCB] TEST PASSED` / `[SCB] TEST FAILED` from the scoreboard.

---

## 6. What was changed in the existing files

- **All comments removed** from every `.sv` file in the testbenches. Only comment text
  was taken out; the code is token-for-token the same as before.
- `Decoder_tb_top.sv` and `Controller_tb_top.sv` read `+NUMTXN=` (default 1000).
- `LSU/lsu_top.sv`, `LSU/lsu_assertions.sv`: `zeroriscy_*` names changed to the core's
  `rv32i_load_store_unit` / `rv32i_defines.vh`.
- Register file: `Reg_Transaction.sv` width bug fixed (`[DATA_WIDTH-10]` ->
  `[DATA_WIDTH-1:0]`), `Reg_monitor.sv` and `Reg_Coverage.sv` completed, an `"all"`
  test added to `Reg_Generator.sv`, and the missing scoreboard, assertions, env and
  tb_top written.
- RTL each testbench needs is copied into its own `RTL/` folder from
  `RV32I_zeroriscy/rtl/core/`, with the decoder's `rv32i_defines.vh` (the one with the
  include guard). If you change the core RTL, copy it again.

---

## 7. Open points

- `rv32i_core.v` (the full core) is an integration of all of the above and is best
  verified with programs on the SoC testbench in `RV32I_zeroriscy/`, not with a unit
  testbench.
- `DBG_WAIT_BRANCH` in the controller is declared but no transition leads to it.
- `out_valid_stored_o` of the fetch FIFO is unused by the prefetch buffer; it is only
  covered, not checked.
- Build output (`ALU/work`, `*/sim/work`, `covhtmlreport`, `.ucdb`, `.wlf`, `transcript`)
  and the `ALU.zip` / `1TOPS_VERIFICATION.zip` files are committed. These are
  regenerated on every run and can be dropped from git.
