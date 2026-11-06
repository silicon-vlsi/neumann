"""Compile and run the register_file SV testbench in QuestaSim.

Usage:
    python scripts/run_sim.py                 # batch run, prints summary
    python scripts/run_sim.py --trans 5000    # number of transactions (+NUMTXN)
    python scripts/run_sim.py --seed 42       # fixed random seed
    python scripts/run_sim.py --cov           # code + functional coverage, HTML report
    python scripts/run_sim.py --gui           # open in the Questa GUI
    python scripts/run_sim.py --clean         # delete the sim folder first
    python scripts/run_sim.py --test x0       # one generator test instead of all (random, write, read, write_read, x0, corner, same_addr, test_en)
    python scripts/run_sim.py -v              # print the full simulation log
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RTL = ROOT / "RTL"
TB = ROOT / "SV_TB"
WORK = ROOT / "sim"
TOP = "Reg_tb_top"

# RTL first, then interface, assertions (has the bind) and the top that includes the classes
SOURCES = [
    RTL / "cluster_clock_gating.v",
    RTL / "rv32i_register_file.v",
    TB / "Reg_interface.sv",
    TB / "Reg_Assertions.sv",
    TB / "Reg_tb_top.sv",
]


def run(cmd, log):
    print(">", " ".join(str(c) for c in cmd))
    res = subprocess.run([str(c) for c in cmd], cwd=WORK, capture_output=True, text=True)
    out = res.stdout + res.stderr
    (WORK / log).write_text(out)
    return res.returncode, out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--trans", type=int, default=1000, help="number of transactions (default 1000)")
    ap.add_argument("--seed", default="random", help="sv_seed value (default: random)")
    ap.add_argument("--cov", action="store_true", help="collect coverage and write an HTML report")
    ap.add_argument("--gui", action="store_true", help="open the Questa GUI")
    ap.add_argument("--clean", action="store_true", help="delete the sim folder first")
    ap.add_argument("--test", default="all", help="generator test to run (default: all)")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the full log")
    args = ap.parse_args()

    if args.clean and WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(exist_ok=True)

    if not (WORK / "work").exists():
        run(["vlib", "work"], "vlib.log")

    # -mfcu is required, otherwise the bind in Reg_Assertions.sv is dropped
    vlog = ["vlog", "-sv", "-mfcu", "-timescale", "1ns/1ps", f"+incdir+{TB}", f"+incdir+{RTL}"]
    if args.cov:
        vlog += ["-cover", "bcesft"]
    rc, out = run(vlog + SOURCES, "compile.log")
    if rc != 0 or "** Error" in out:
        print(out)
        sys.exit(f"Compile failed, see {WORK / 'compile.log'}")
    print("Compile OK")

    vsim = ["vsim", "-sv_seed", args.seed, f"+NUMTXN={args.trans}"]
    vsim.append(f"+TEST={args.test}")
    if args.cov:
        vsim.append("-coverage")
    if args.gui:
        subprocess.run([str(c) for c in vsim + ["-voptargs=+acc", "-do", "add wave -r /*; run -all", TOP]], cwd=WORK)
        return

    do = "run -all; quit -f"
    if args.cov:
        do = "coverage save -onexit reg.ucdb; run -all; quit -f"
    rc, out = run(vsim + ["-c", "-do", do, TOP], "sim.log")
    if args.verbose:
        print(out)
    else:
        for line in out.splitlines():
            if any(k in line for k in ("[ENV]", "[SCB]", "[COV]", "[TOP]", "[GEN] directed",
                                       "** Error", "** Fatal", "ERROR", "Sv_Seed")):
                print(line)
    print(f"Full log: {WORK / 'sim.log'}")

    if args.cov:
        run(["vcover", "report", "-details", "-output", "coverage.txt", "reg.ucdb"], "vcover.log")
        run(["vcover", "report", "-html", "-details", "-output", "covhtmlreport", "reg.ucdb"], "vcover.log")
        print("Coverage report:", WORK / "covhtmlreport" / "index.html")

    passed = rc == 0 and "TEST PASSED" in out and "** Error" not in out and "** Fatal" not in out
    print("RESULT:", "PASS" if passed else "FAIL")
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
