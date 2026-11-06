# LSU Layered Testbench (modular, class-based) + clock gating

For `rv32i_load_store_unit`. Same layered style as ALU TB, plus a
memory-slave agent (sequential DUT needs one) and FSM coverage.

## Flow
```
generator --mbx--> driver --> DUT(lsu_if) <-- mem_slave (handshake + backing mem)
                                  |
                               monitor --+--> scoreboard (mirror-mem check)
                                         +--> coverage_inf (functional + FSM cov)
```

## Files
| File            | Role |
|-----------------|------|
| lsu_if.sv       | interface: all pins + drv/mem/mon clocking blocks + dbg_cs |
| transaction.sv  | access packet (we/type/addr/wdata/sext) |
| generator.sv    | directed (size x off x we x sext) + N random |
| driver.sv       | drives EX-side req, waits gnt then data_valid_o |
| mem_slave.sv    | OBI-like slave: gnt/rvalid handshake, backing mem, latency knobs |
| monitor.sv      | samples completed accesses -> scb + cov |
| scoreboard.sv   | mirror memory, predicts load rdata + BE, checks |
| coverage_inf.sv | functional covergroup + FSM covergroup (vif.dbg_cs) |
| environment.sv  | builds + wires + runs all |
| test.sv         | scenario, applies knobs |
| lsu_pkg.sv      | includes all classes |
| lsu_assertions.sv | SVA bound into DUT (handshake + FSM + BE checks) |
| lsu_top.sv      | clock + CLOCK GATING + interface + DUT + bind SVA + knobs + launch |

## KNOBS (all in lsu_top.sv)
```
parameter int NUM_RAND_TXN = 500;   // <-- number of random transactions
parameter int GNT_DELAY    = 1;     // memory grant latency (WAIT_GNT coverage)
parameter int RVALID_DELAY = 1;     // memory data latency
parameter time CLK_PERIOD  = 10ns;
```
Override at compile without editing file, e.g.:
```
vsim lsu_top -GNUM_RAND_TXN=2000 -GGNT_DELAY=3 ...
vcs ... -pvalue+lsu_top.NUM_RAND_TXN=2000
```

## CLOCK GATING (clock enable)
Top makes raw `clk_src`, ANDs with `clk_en` through a low-transparent latch
(standard glitch-free ICG) to make gated `clk` feeding the DUT.
- `clk_en = 1` -> DUT clock runs.
- `clk_en = 0` -> DUT clock gated OFF (held), DUT frozen.
Uncomment the optional block in lsu_top.sv to pause the clock mid-run and prove
the LSU resumes cleanly.

## Run
```sh
# VCS
vcs -sverilog -full64 -cm line+cond+fsm+tgl+branch \
    +incdir+. +incdir+<defines_dir> \
    rv32i_load_store_unit.v lsu_if.sv lsu_assertions.sv lsu_pkg.sv lsu_top.sv
simv -cm line+cond+fsm+tgl+branch
urg -dir simv.vdb

# Questa
vlog +cover=bcefst +incdir+. +incdir+<defines_dir> \
     rv32i_load_store_unit.v lsu_if.sv lsu_assertions.sv lsu_pkg.sv lsu_top.sv
vsim -coverage -c lsu_top -do "run -all; coverage report -detail; quit"

# Xcelium
xrun -coverage all +incdir+. +incdir+<defines_dir> \
     rv32i_load_store_unit.v lsu_if.sv lsu_assertions.sv lsu_pkg.sv lsu_top.sv
```

## Edit before run
- `+incdir` -> this folder AND your `rv32i_defines.vh`.
- Top DUT instance name is `dut`; FSM cov routes `dut.CS` -> `vif.dbg_cs`.
  If the RTL state reg isn't named `CS`, fix that one assign in lsu_top.sv.
- scoreboard mirror mem init MUST match mem_slave init (`mem[i]=i[7:0]`) — both set.
- Misaligned BE isn't modeled in scoreboard (BE check skipped when misaligned);
  load data IS still checked for misaligned.
```
