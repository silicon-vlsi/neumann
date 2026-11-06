"""One script to run the verification of any core component in QuestaSim.

Every block (ALU, Imm_gen, decoder, int_controller, LSU, register file) has its
own SV testbench in its own folder. This script knows the file list, the top
module and the pass message of each one, so I don't have to remember them.

Usage (from the 1TOPS_VERIFICATION folder):
    python run_verification.py --list                  # show all components
    python run_verification.py alu                     # run one component
    python run_verification.py decoder lsu             # run a few
    python run_verification.py all                     # full regression
    python run_verification.py imm_gen --trans 5000    # number of transactions
    python run_verification.py alu --cov               # coverage + HTML report
    python run_verification.py lsu --seed 42           # fixed random seed
    python run_verification.py decoder --gui           # open the Questa GUI
    python run_verification.py all --clean             # delete old sim folders first
    python run_verification.py lsu --vsim-args="-GGNT_DELAY=3 -GRVALID_DELAY=2"

All build output goes to <component>/sim/ so the RTL and TB folders stay clean.
Exit code is 0 only if every component that ran has PASSED.
"""
import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent

# each entry is one block of the core
#   dir     : component folder
#   sources : compile order matters (DUT, interface, then pkg / tb_top)
#   incdirs : folders with the `include files (defines + classes)
#   top     : top module for vsim
#   mfcu    : needed when the bind lives in a separate assertions file
#   trans   : how the testbench takes the transaction count, {n} is replaced
#   passmsg : what the scoreboard prints when everything matched
COMPONENTS = {
    "alu": dict(
        dir="ALU",
        sources=["rv32i_Alu.v", "alu_pkg.sv", "alu_if.sv", "alu_assertions.sv", "alu_top.sv"],
        incdirs=["."],
        top="alu_top",
        mfcu=False,
        trans="+num_trans={n}",
        default_trans=200,
        passmsg="RESULT: *** PASS ***",
        note="transactions are per opcode (22 opcodes)",
    ),
    "imm_gen": dict(
        dir="Imm_gen",
        sources=["RTL/rv32i_imm_gen.v", "SV_TB/imm_Interface.sv", "SV_TB/tb_top.sv"],
        incdirs=["RTL", "SV_TB"],
        top="tb_top",
        mfcu=False,
        trans="+NUMTXN={n}",
        default_trans=1000,
        passmsg="TEST PASSED",
    ),
    "decoder": dict(
        dir="rv32i_decoder",
        sources=["RTL/rv32i_decoder.v", "SV_tb/Decoder_interface.sv",
                 "SV_tb/Decoder_Assertions.sv", "SV_tb/Decoder_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Decoder_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=1000,
        passmsg="TEST PASSED",
    ),
    "int_controller": dict(
        dir="int_controller",
        sources=["RTL/rv32i_int_controller.v", "SV_tb/Controller_interface.sv",
                 "SV_tb/Controller_Assertions.sv", "SV_tb/Controller_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Controller_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=1000,
        passmsg="TEST PASSED",
    ),
    "lsu": dict(
        dir="LSU",
        sources=["rv32i_load_store_unit.v", "lsu_if.sv", "lsu_assertions.sv", "lsu_pkg.sv", "lsu_top.sv"],
        incdirs=["."],
        top="lsu_top",
        mfcu=False,
        trans="-GNUM_RAND_TXN={n}",
        default_trans=500,
        passmsg="RESULT: *** PASS ***",
        note="transactions are the random ones, directed ones always run",
    ),
    "register_file": dict(
        dir="rv32i_register_file",
        sources=["RTL/cluster_clock_gating.v", "RTL/rv32i_register_file.v",
                 "SV_TB/Reg_interface.sv", "SV_TB/Reg_Assertions.sv", "SV_TB/Reg_tb_top.sv"],
        incdirs=["SV_TB", "RTL"],
        top="Reg_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=1000,
        passmsg="TEST PASSED",
        note="runs all 8 generator tests back to back, pick one with --vsim-args=\"+TEST=x0\"",
    ),
    "ex_block": dict(
        dir="rv32i_ex_block",
        sources=["RTL/rv32i_Alu.v", "RTL/rv32i_ex_block.v", "SV_tb/Ex_interface.sv",
                 "SV_tb/Ex_Assertions.sv", "SV_tb/Ex_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Ex_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=1000,
        passmsg="TEST PASSED",
        note="directed corner sweep of all 22 ALU ops always runs first",
    ),
    "compressed_decoder": dict(
        dir="rv32i_compressed_decoder",
        sources=["RTL/rv32i_compressed_decoder.v", "SV_tb/Cdec_interface.sv",
                 "SV_tb/Cdec_Assertions.sv", "SV_tb/Cdec_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Cdec_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=1000,
        passmsg="TEST PASSED",
        note="all 49152 compressed encodings are swept first, +NOSWEEP skips it",
    ),
    "fetch_fifo": dict(
        dir="rv32i_fetch_fifo",
        sources=["RTL/rv32i_fetch_fifo.v", "SV_tb/Fifo_interface.sv", "SV_tb/Fifo_Assertions.sv",
                 "SV_tb/Fifo_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Fifo_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=2000,
        passmsg="TEST PASSED",
        note="transactions are clock cycles",
    ),
    "prefetch_buffer": dict(
        dir="rv32i_prefetch_buffer",
        sources=["RTL/rv32i_fetch_fifo.v", "RTL/rv32i_prefetch_buffer.v",
                 "SV_tb/Pref_interface.sv", "SV_tb/Pref_Assertions.sv", "SV_tb/Pref_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Pref_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=2000,
        passmsg="TEST PASSED",
        note="transactions are clock cycles",
    ),
    "cs_registers": dict(
        dir="rv32i_cs_registers",
        sources=["RTL/rv32i_cs_registers.v", "SV_tb/Csr_interface.sv", "SV_tb/Csr_Assertions.sv",
                 "SV_tb/Csr_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Csr_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=2000,
        passmsg="TEST PASSED",
        note="transactions are clock cycles",
    ),
    "debug_unit": dict(
        dir="rv32i_debug_unit",
        sources=["RTL/rv32i_debug_unit.v", "SV_tb/Dbg_interface.sv", "SV_tb/Dbg_Assertions.sv",
                 "SV_tb/Dbg_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Dbg_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=2000,
        passmsg="TEST PASSED",
        note="transactions are clock cycles",
    ),
    "controller": dict(
        dir="rv32i_controller",
        sources=["RTL/rv32i_controller.v", "SV_tb/Ctrl_interface.sv", "SV_tb/Ctrl_Assertions.sv",
                 "SV_tb/Ctrl_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Ctrl_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=2000,
        passmsg="TEST PASSED",
        note="transactions are clock cycles",
    ),
    "if_stage": dict(
        dir="rv32i_if_stage",
        sources=["RTL/rv32i_fetch_fifo.v", "RTL/rv32i_prefetch_buffer.v",
                 "RTL/rv32i_compressed_decoder.v", "RTL/rv32i_if_stage.v", "SV_tb/If_interface.sv",
                 "SV_tb/If_Assertions.sv", "SV_tb/If_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="If_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=2000,
        passmsg="TEST PASSED",
        note="transactions are clock cycles",
    ),
    "id_stage": dict(
        dir="rv32i_id_stage",
        sources=["RTL/cluster_clock_gating.v", "RTL/rv32i_register_file.v", "RTL/rv32i_decoder.v",
                 "RTL/rv32i_controller.v", "RTL/rv32i_int_controller.v", "RTL/rv32i_id_stage.v",
                 "SV_tb/Id_interface.sv", "SV_tb/Id_Assertions.sv", "SV_tb/Id_tb_top.sv"],
        incdirs=["SV_tb", "RTL"],
        top="Id_tb_top",
        mfcu=True,
        trans="+NUMTXN={n}",
        default_trans=2000,
        passmsg="TEST PASSED",
        note="transactions are clock cycles",
    ),
}

# short names so I can type less
ALIASES = {
    "imm": "imm_gen", "immgen": "imm_gen",
    "dec": "decoder", "rv32i_decoder": "decoder",
    "int": "int_controller", "intc": "int_controller", "irq": "int_controller",
    "load_store_unit": "lsu",
    "rf": "register_file", "regfile": "register_file", "rv32i_register_file": "register_file",
    "ex": "ex_block", "rv32i_ex_block": "ex_block",
    "cdec": "compressed_decoder", "rvc": "compressed_decoder", "rv32i_compressed_decoder": "compressed_decoder",
    "fifo": "fetch_fifo", "rv32i_fetch_fifo": "fetch_fifo",
    "pref": "prefetch_buffer", "prefetch": "prefetch_buffer", "rv32i_prefetch_buffer": "prefetch_buffer",
    "csr": "cs_registers", "rv32i_cs_registers": "cs_registers",
    "dbg": "debug_unit", "debug": "debug_unit", "rv32i_debug_unit": "debug_unit",
    "ctrl": "controller", "rv32i_controller": "controller",
    "if": "if_stage", "ifs": "if_stage", "rv32i_if_stage": "if_stage",
    "id": "id_stage", "ids": "id_stage", "rv32i_id_stage": "id_stage",
}

# lines worth showing on the terminal when not in verbose mode
KEYS = ("[ENV]", "[SCB]", "[COV]", "[TOP]", "RESULT", "PASS=", "SCOREBOARD",
        "Functional cov", "FSM cov", "** Error", "** Fatal", "ERROR", "Sv_Seed", "Errors:")


def run(cmd, cwd, log=None, show=False):
    print(">", " ".join(str(c) for c in cmd))
    res = subprocess.run([str(c) for c in cmd], cwd=cwd, capture_output=True, text=True)
    out = res.stdout + res.stderr
    if log:
        (cwd / log).write_text(out)
    if show:
        print(out)
    return res.returncode, out


def check_tools(need_cov):
    tools = ["vlib", "vlog", "vsim"] + (["vcover"] if need_cov else [])
    missing = [t for t in tools if shutil.which(t) is None]
    if missing:
        sys.exit(f"ERROR: {', '.join(missing)} not found in PATH. "
                 "Add the QuestaSim win64 (or linux_x86_64) folder to PATH.")


def resolve(names):
    if not names or "all" in [n.lower() for n in names]:
        return list(COMPONENTS)
    picked = []
    for n in names:
        key = ALIASES.get(n.lower(), n.lower())
        if key not in COMPONENTS:
            sys.exit(f"ERROR: unknown component '{n}'. Use --list to see them.")
        if key not in picked:
            picked.append(key)
    return picked


def list_components():
    print(f"{'name':<20}{'folder':<26}{'top':<20}{'default trans':<15}status")
    print("-" * 95)
    for name, c in COMPONENTS.items():
        root = HERE / c["dir"]
        missing = [s for s in c["sources"] if not (root / s).exists()]
        status = "ready" if not missing else f"missing {', '.join(missing)}"
        print(f"{name:<20}{c['dir']:<26}{c['top']:<20}{c['default_trans']:<15}{status}")
    print("\naliases:", ", ".join(f"{a}->{k}" for a, k in ALIASES.items()))


def run_component(name, args):
    c = COMPONENTS[name]
    root = HERE / c["dir"]
    sim = root / "sim"
    print("\n" + "=" * 60)
    print(f" {name.upper()}  ({c['dir']})")
    if c.get("note"):
        print(f" note: {c['note']}")
    print("=" * 60)

    # don't even try if the TB isn't complete yet
    missing = [s for s in c["sources"] if not (root / s).exists()]
    if missing:
        print("SKIP: missing", ", ".join(missing))
        return dict(name=name, result="SKIP", seed="-", cov="-", time=0.0, log="-")

    start = time.time()
    if args.clean and sim.exists():
        shutil.rmtree(sim)
    sim.mkdir(exist_ok=True)

    if not (sim / "work").exists():
        run(["vlib", "work"], sim, "vlib.log")

    # ---- compile ----
    # -timescale gives the files without a `timescale (e.g. lsu_if.sv) the same 1ns/1ps,
    # otherwise vsim stops with vsim-3009
    vlog = ["vlog", "-sv", "-timescale", "1ns/1ps"]
    if c["mfcu"]:
        # -mfcu is required, otherwise the bind in the assertions file is dropped
        vlog.append("-mfcu")
    if args.cov:
        vlog += ["-cover", "bcesft"]
    vlog += [f"+incdir+{root / d}" for d in c["incdirs"]]
    vlog += [root / s for s in c["sources"]]
    rc, out = run(vlog, sim, "compile.log")
    if rc != 0 or "** Error" in out:
        print(out)
        print(f"COMPILE FAILED - see {sim / 'compile.log'}")
        return dict(name=name, result="COMPILE FAIL", seed="-", cov="-",
                    time=time.time() - start, log=str(sim / "compile.log"))
    print("Compile OK")

    # ---- simulate ----
    trans = args.trans if args.trans else c["default_trans"]
    vsim = ["vsim", "-sv_seed", str(args.seed), c["trans"].format(n=trans)]
    if args.cov:
        vsim.append("-coverage")
    if args.vsim_args:
        vsim += shlex.split(args.vsim_args)

    if args.gui:
        do = "add wave -r /*; run -all"
        if args.cov:
            do = f"coverage save -onexit {name}.ucdb; " + do
        subprocess.run([str(x) for x in vsim + ["-voptargs=+acc", "-do", do, c["top"]]], cwd=sim)
        return dict(name=name, result="GUI", seed=str(args.seed), cov="-",
                    time=time.time() - start, log="-")

    do = "run -all; quit -f"
    if args.cov:
        do = f"coverage save -onexit {name}.ucdb; run -all; quit -f"
    rc, out = run(["vsim", "-c"] + vsim[1:] + ["-do", do, c["top"]], sim, "sim.log")

    if args.verbose:
        print(out)
    else:
        for line in out.splitlines():
            if any(k in line for k in KEYS):
                print(line)

    seed = re.search(r"Sv_Seed\s*=\s*(\d+)", out)
    seed = seed.group(1) if seed else str(args.seed)
    # ALU/LSU print "Functional cov(erage) = x %", the others print "[COV] coverage = x %"
    cov = re.findall(r"(?:\[COV\]|Functional cov)[^\n=]*=\s*([\d.]+)\s*%", out)
    cov = f"{cov[-1]}%" if cov else "-"

    # ---- coverage report ----
    if args.cov and (sim / f"{name}.ucdb").exists():
        run(["vcover", "report", "-details", "-output", "coverage.txt", f"{name}.ucdb"], sim)
        run(["vcover", "report", "-html", "-details", "-output", "covhtmlreport", f"{name}.ucdb"], sim)
        print("Coverage report:", sim / "covhtmlreport" / "index.html")

    passed = (rc == 0 and c["passmsg"] in out
              and "** Error" not in out and "** Fatal" not in out
              and "global timeout" not in out)
    print("RESULT:", "PASS" if passed else "FAIL", "| log:", sim / "sim.log")
    return dict(name=name, result="PASS" if passed else "FAIL", seed=seed, cov=cov,
                time=time.time() - start, log=str(sim / "sim.log"))


def summary(results):
    lines = ["", "=" * 82,
             f"{'component':<20}{'result':<14}{'seed':<14}{'func cov':<10}{'time':<8}",
             "-" * 82]
    for r in results:
        lines.append(f"{r['name']:<20}{r['result']:<14}{r['seed']:<14}{r['cov']:<10}{r['time']:>6.1f}s")
    lines.append("=" * 82)
    text = "\n".join(lines)
    print(text)
    # keep a copy so I can check the last regression later
    (HERE / "regression_summary.txt").write_text(
        time.strftime("%Y-%m-%d %H:%M:%S") + "\n" + text + "\n"
        + "\n".join(f"{r['name']}: {r['log']}" for r in results) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("components", nargs="*", help="component names, or 'all' (default: all)")
    ap.add_argument("--list", action="store_true", help="list the components and exit")
    ap.add_argument("--trans", type=int, default=0, help="number of transactions (default: per component)")
    ap.add_argument("--seed", default="random", help="sv_seed value (default: random)")
    ap.add_argument("--cov", action="store_true", help="collect coverage and write an HTML report")
    ap.add_argument("--gui", action="store_true", help="open the Questa GUI with all waves")
    ap.add_argument("--clean", action="store_true", help="delete the sim folder first")
    ap.add_argument("--vsim-args", default="", help="extra args passed straight to vsim")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the full sim log")
    args = ap.parse_args()

    if args.list:
        list_components()
        return

    names = resolve(args.components)
    if args.gui and len(names) > 1:
        sys.exit("ERROR: --gui works with one component at a time.")
    check_tools(args.cov)

    results = [run_component(n, args) for n in names]
    if not args.gui:
        summary(results)

    failed = [r for r in results if r["result"] not in ("PASS", "SKIP", "GUI")]
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
