# ALU Layered Testbench (modular, class-based)

Matches your file structure: transaction / generator / driver / monitor /
scoreboard / coverage / environment / test + interface + pkg + top.

## Flow
```
generator --mbx--> driver --> DUT(alu_if) --> monitor --+--> scoreboard (golden check)
                                                        +--> coverage_inf (functional cov)
environment builds+wires all. test loads opcode list. alu_top = static harness.
```

## Files
| File              | Role |
|-------------------|------|
| alu_if.sv         | interface: DUT pins + drv/mon clocking blocks |
| transaction.sv    | packet: rand inputs + expected/captured outputs |
| generator.sv      | makes txns (directed corners + constrained random) |
| driver.sv         | drives txns onto DUT via drv_cb |
| monitor.sv        | samples DUT, forwards to scb + cov |
| scoreboard.sv     | golden model + pass/fail check |
| coverage_inf.sv   | functional covergroup + % report |
| environment.sv    | builds mailboxes + components, runs them |
| test.sv           | scenario: opcode sweep list |
| alu_pkg.sv        | includes all classes + defines |
| alu_top.sv        | clock + interface + DUT + launch test |

## Run
Compile DUT + defines + pkg + top together. `+incdir` must point to
`zeroriscy_defines.vh` AND this folder (classes are `` `include ``-d in the pkg).

```sh
# --- VCS (functional + code coverage) ---
vcs -sverilog -full64 -cm line+cond+fsm+tgl+branch \
    +incdir+. +incdir+<defines_dir> \
    zeroriscy_alu.v alu_if.sv alu_pkg.sv alu_top.sv
simv -cm line+cond+fsm+tgl+branch
urg -dir simv.vdb            # merged coverage report

# --- Questa/ModelSim (Using run.py) ---
You can use the provided Python script `run.py` to automate compilation, simulation, and coverage reporting.
It handles creating the work library, compiling the SV files, and running `vsim` with specific flags.

### Basic Run
Run in batch mode with default 200 transactions:
```sh
python run.py
```

### Advanced Run Options
- Change the number of transactions with `--trans`:
  `python run.py --trans 500`
- Enable Code & Functional Coverage with `--cov` (Generates an HTML report in `covhtmlreport/`):
  `python run.py --cov`
- Open the QuestaSim GUI to view waveforms with `--gui`:
  `python run.py --gui`
- Clean the previous compilation databases with `--clean`:
  `python run.py --clean`

**Example:** Clean, enable coverage, run 1000 transactions, and open the GUI:
```sh
python run.py --clean --cov --trans 1000 --gui
```

# --- Xcelium ---
xrun -coverage all +incdir+. +incdir+<defines_dir> \
     zeroriscy_alu.v alu_if.sv alu_pkg.sv alu_top.sv
```

## Edit before running
- `alu_if.sv` OP_W default (or pass `#(.OP_W(`ALU_OP_WIDTH))` — already done in top).
- Opcode macro names in scoreboard/coverage/test must match your defines file.
- If you don't have `zeroriscy_defines.vh`, replace the `` `include `` with
  localparams for each `ALU_*`.
- `test.sv` op_list / num_per_op to tune run length.
