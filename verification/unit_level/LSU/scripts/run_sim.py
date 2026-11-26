"""Compile and run the LSU SV testbench in QuestaSim.

Usage:
    python scripts/run_sim.py                  # batch run, prints summary
    python scripts/run_sim.py --trans 2000     # number of random transactions
    python scripts/run_sim.py --gnt 3 --rvalid 2   # memory latency knobs
    python scripts/run_sim.py --seed 42        # fixed random seed
    python scripts/run_sim.py --cov            # code + functional coverage, HTML report
    python scripts/run_sim.py --gui            # open in the Questa GUI
    python scripts/run_sim.py -v               # print the full simulation log
"""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "sim"
TOP = "lsu_top"

# lsu_if before lsu_pkg, the classes use the virtual interface
SOURCES = [
    ROOT / "rv32i_load_store_unit.v",
    ROOT / "lsu_if.sv",
    ROOT / "lsu_assertions.sv",
    ROOT / "lsu_pkg.sv",
    ROOT / "lsu_top.sv",
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
    ap.add_argument("--trans", type=int, default=500, help="random transactions (default 500)")
    ap.add_argument("--gnt", type=int, default=1, help="memory grant delay (default 1)")
    ap.add_argument("--rvalid", type=int, default=1, help="memory rvalid delay (default 1)")
    ap.add_argument("--seed", default="random", help="sv_seed value (default: random)")
    ap.add_argument("--cov", action="store_true", help="collect coverage and write an HTML report")
    ap.add_argument("--gui", action="store_true", help="open the Questa GUI")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the full log")
    args = ap.parse_args()

    WORK.mkdir(exist_ok=True)

    if not (WORK / "work").exists():
        run(["vlib", "work"], "vlib.log")

    vlog = ["vlog", "-sv", "-timescale", "1ns/1ps", f"+incdir+{ROOT}"]
    if args.cov:
        vlog += ["-cover", "bcesft"]
    rc, out = run(vlog + SOURCES, "compile.log")
    if rc != 0:
        print(out)
        sys.exit(f"Compile failed, see {WORK / 'compile.log'}")
    print("Compile OK")

    # knobs are parameters of lsu_top, so they go in with -G
    vsim = ["vsim", "-sv_seed", args.seed,
            f"-GNUM_RAND_TXN={args.trans}", f"-GGNT_DELAY={args.gnt}",
            f"-GRVALID_DELAY={args.rvalid}"]
    if args.cov:
        vsim.append("-coverage")
    if args.gui:
        subprocess.run([str(c) for c in vsim + ["-voptargs=+acc", "-do", "add wave -r /*; run -all", TOP]],
                       cwd=WORK)
        return

    do = "run -all; quit -f"
    if args.cov:
        do = "coverage save -onexit lsu.ucdb; run -all; quit -f"
    rc, out = run(vsim + ["-c", "-do", do, TOP], "sim.log")
    if args.verbose:
        print(out)
    else:
        for line in out.splitlines():
            if any(k in line for k in ("SCOREBOARD", "PASS=", "RESULT", "cov",
                                       "LSU:", "** Error", "** Fatal", "ERROR", "Sv_Seed")):
                print(line)
    print(f"Full log: {WORK / 'sim.log'}")

    if args.cov:
        run(["vcover", "report", "-details", "-output", "coverage.txt", "lsu.ucdb"], "vcover.log")
        run(["vcover", "report", "-html", "-details", "-output", "covhtmlreport", "lsu.ucdb"], "vcover.log")
        print("Coverage report:", WORK / "covhtmlreport" / "index.html")

    passed = (rc == 0 and "RESULT: *** PASS ***" in out
              and "** Error" not in out and "** Fatal" not in out)
    print("RESULT:", "PASS" if passed else "FAIL")
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
