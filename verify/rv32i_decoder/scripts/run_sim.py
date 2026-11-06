"""Compile and run the rv32i_decoder SV testbench in QuestaSim.

Usage:
    python scripts/run_sim.py              # batch run, prints summary
    python scripts/run_sim.py --seed 42    # fixed random seed
    python scripts/run_sim.py --gui        # open in the Questa GUI
    python scripts/run_sim.py -v           # print the full simulation log
"""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RTL = ROOT / "RTL"
TB = ROOT / "SV_tb"
WORK = ROOT / "sim"
TOP = "Decoder_tb_top"

SOURCES = [
    RTL / "rv32i_decoder.v",
    TB / "Decoder_interface.sv",
    TB / "Decoder_Assertions.sv",
    TB / "Decoder_tb_top.sv",
]


def run(cmd, log):
    print(">", " ".join(str(c) for c in cmd))
    res = subprocess.run(cmd, cwd=WORK, capture_output=True, text=True)
    out = res.stdout + res.stderr
    (WORK / log).write_text(out)
    return res.returncode, out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", default="random", help="sv_seed value (default: random)")
    ap.add_argument("--gui", action="store_true", help="open the Questa GUI")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the full log")
    args = ap.parse_args()

    WORK.mkdir(exist_ok=True)

    if not (WORK / "work").exists():
        run(["vlib", "work"], "vlib.log")

    # -mfcu is required, otherwise the bind in Decoder_Assertions.sv is dropped
    rc, out = run(["vlog", "-sv", "-mfcu", f"+incdir+{TB}", f"+incdir+{RTL}",
                   *SOURCES], "compile.log")
    if rc != 0:
        print(out)
        sys.exit(f"Compile failed, see {WORK / 'compile.log'}")
    print("Compile OK")

    vsim = ["vsim", "-voptargs=+acc", "-sv_seed", args.seed, TOP]
    if args.gui:
        subprocess.run(vsim + ["-do", "add wave -r /*; run -all"], cwd=WORK)
        return

    rc, out = run(vsim + ["-c", "-do", "run -all; quit -f"], "sim.log")
    if args.verbose:
        print(out)
    else:
        for line in out.splitlines():
            if any(k in line for k in ("[ENV]", "[SCB]", "[COV]", "DECODER",
                                       "** Error", "** Fatal", "Sv_Seed")):
                print(line)
    print(f"Full log: {WORK / 'sim.log'}")

    passed = rc == 0 and "TEST PASSED" in out and "** Error" not in out
    print("RESULT:", "PASS" if passed else "FAIL")
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
