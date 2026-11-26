"""Compile and run the Imm_gen SV testbench in QuestaSim.

Usage (from anywhere):
    python scripts/run_imm_gen.py                 # 1000 transactions, batch mode
    python scripts/run_imm_gen.py --trans 5000    # number of transactions (+NUMTXN)
    python scripts/run_imm_gen.py --cov           # code + functional coverage, HTML report
    python scripts/run_imm_gen.py --gui           # open the QuestaSim GUI with waves
    python scripts/run_imm_gen.py --seed 42       # fixed random seed (default: random)
    python scripts/run_imm_gen.py --clean         # delete the sim directory first

All build output goes to Imm_gen/sim/ so the RTL and SV_TB folders stay clean.
Exit code is 0 only if the scoreboard prints TEST PASSED.
"""
import argparse
import os
import shutil
import subprocess
import sys

ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL    = os.path.join(ROOT, "RTL")
TB     = os.path.join(ROOT, "SV_TB")
SIMDIR = os.path.join(ROOT, "sim")

# Compile order: DUT, interface, then tb_top (which `includes all the classes).
SOURCES = [
    os.path.join(RTL, "rv32i_imm_gen.v"),
    os.path.join(TB, "imm_Interface.sv"),
    os.path.join(TB, "tb_top.sv"),
]


def run(cmd, log=None):
    print(">>", " ".join(cmd))
    proc = subprocess.run(cmd, cwd=SIMDIR, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(proc.stdout)
    if log:
        with open(os.path.join(SIMDIR, log), "w") as f:
            f.write(proc.stdout)
    return proc


def main():
    ap = argparse.ArgumentParser(description="Run the Imm_gen testbench in QuestaSim")
    ap.add_argument("--trans", type=int, default=1000, help="number of transactions (default 1000)")
    ap.add_argument("--seed", default="random", help="sv_seed value (default: random)")
    ap.add_argument("--cov", action="store_true", help="collect coverage and write an HTML report")
    ap.add_argument("--gui", action="store_true", help="open the GUI instead of batch mode")
    ap.add_argument("--clean", action="store_true", help="delete the sim directory first")
    args = ap.parse_args()

    for tool in ("vlib", "vlog", "vsim"):
        if shutil.which(tool) is None:
            sys.exit(f"ERROR: '{tool}' not found in PATH. Add the QuestaSim win64 folder to PATH.")

    if args.clean and os.path.isdir(SIMDIR):
        shutil.rmtree(SIMDIR)
    os.makedirs(SIMDIR, exist_ok=True)

    if not os.path.isdir(os.path.join(SIMDIR, "work")):
        run(["vlib", "work"])

    # ---- compile ----
    vlog = ["vlog", "-sv", f"+incdir+{RTL}", f"+incdir+{TB}"]
    if args.cov:
        vlog += ["-cover", "bcest"]
    if run(vlog + SOURCES, log="compile.log").returncode != 0:
        sys.exit("COMPILE FAILED - see sim/compile.log")

    # ---- simulate ----
    vsim = ["vsim", "-sv_seed", str(args.seed), f"+NUMTXN={args.trans}"]
    if args.cov:
        vsim.append("-coverage")
    if args.gui:
        vsim += ["-voptargs=+acc", "-do", "add wave -r /tb_top/*; run -all"]
        vsim.append("tb_top")
        subprocess.run(vsim, cwd=SIMDIR)
        return

    do = "run -all; quit -f"
    if args.cov:
        do = "coverage save -onexit imm_gen.ucdb; run -all; quit -f"
    vsim = ["vsim", "-c"] + vsim[1:] + ["-do", do, "tb_top"]
    out = run(vsim, log="sim.log").stdout

    if args.cov:
        run(["vcover", "report", "-details", "-output", "coverage.txt", "imm_gen.ucdb"])
        run(["vcover", "report", "-html", "-output", "covhtmlreport", "imm_gen.ucdb"])
        print("Coverage report:", os.path.join(SIMDIR, "covhtmlreport", "index.html"))

    passed = "TEST PASSED" in out and "** Error" not in out and "** Fatal" not in out
    print("=" * 50)
    print("RESULT:", "PASS" if passed else "FAIL", "| log:", os.path.join(SIMDIR, "sim.log"))
    print("=" * 50)
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
