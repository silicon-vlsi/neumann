import argparse
import subprocess
import sys
import os

def run_cmd(cmd):
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True)
    if result.returncode != 0:
        print(f"Error executing: {cmd}")
        sys.exit(result.returncode)

def main():
    parser = argparse.ArgumentParser(description="Run QuestaSim SV Framework for ALU")
    parser.add_argument("--trans", type=int, default=200, help="Number of transactions per opcode (default: 200)")
    parser.add_argument("--cov", action="store_true", help="Enable code and functional coverage collection")
    parser.add_argument("--gui", action="store_true", help="Open QuestaSim GUI instead of batch mode")
    parser.add_argument("--clean", action="store_true", help="Clean compilation files before running")
    
    args = parser.parse_args()

    # 1. Clean if requested
    if args.clean:
        print("Cleaning previous build files...")
        if os.path.exists("work"):
            run_cmd("vdel -all")
        if os.path.exists("transcript"):
            os.remove("transcript")
        if os.path.exists("cover.ucdb"):
            os.remove("cover.ucdb")

    # 2. Create work library
    if not os.path.exists("work"):
        run_cmd("vlib work")

    # 3. Compile Design and Testbench
    print("\n--- Compiling ---")
    # Coverage flags: b=branch, c=condition, e=expression, s=statement, f=fsm, t=toggle
    cov_comp_flag = "-cover bcesft" if args.cov else ""
    
    # We compile the package first if it exists, then everything else
    compile_cmd = f"vlog -sv {cov_comp_flag} +incdir+. rv32i_Alu.v alu_pkg.sv alu_if.sv alu_assertions.sv alu_top.sv"
    run_cmd(compile_cmd)

    # 4. Simulate
    print("\n--- Simulating ---")
    cov_sim_flag = "-coverage" if args.cov else ""
    gui_flag = "-c" if not args.gui else ""
    
    # vsim options: 
    # -c for batch mode
    # +num_trans to pass our custom parameter to test.sv
    
    if args.gui:
        do_cmd = "add wave -r /*; run -all"
    else:
        if args.cov:
            do_cmd = "coverage save -onexit cover.ucdb; run -all; exit"
        else:
            do_cmd = "run -all; exit"

    sim_cmd = f'vsim {gui_flag} {cov_sim_flag} work.alu_top +num_trans={args.trans} -do "{do_cmd}"'
    run_cmd(sim_cmd)

    # 5. Report Coverage
    if args.cov and not args.gui:
        print("\n--- Generating Coverage Report ---")
        run_cmd("vcover report -html -htmldir covhtmlreport -source -details cover.ucdb")
        print("Coverage report generated in 'covhtmlreport/index.html'")

if __name__ == "__main__":
    main()
