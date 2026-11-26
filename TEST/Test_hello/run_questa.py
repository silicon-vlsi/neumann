#!/usr/bin/env python3
"""run_questa.py - run Test_hello in Questa.

    python run_questa.py            # run, prints the 4 steps and RESULT
    python run_questa.py --gui      # same with the waveform window
    python run_questa.py --cg 0     # clock gating off
"""
import argparse, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))       # neumann_soc/
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook                                                 # finds vlib / vlog / vsim

ap = argparse.ArgumentParser()
ap.add_argument('--cg', type=int, default=1, choices=[0, 1])
ap.add_argument('--gui', action='store_true')
a = ap.parse_args()

# the answer key and the program image (both made by Python, no compiler needed)
subprocess.run([sys.executable, os.path.join(HERE, 'programs', 'gen_golden.py')], check=True)
subprocess.run([sys.executable, os.path.join(HERE, 'programs', 'mkhex.py')], check=True,
               stdout=subprocess.DEVNULL)

os.chdir(ROOT)                                # all paths below are relative to neumann_soc/
B = 'TEST/Test_hello/build'
os.makedirs(B, exist_ok=True)
work = B + '/work'
covhook.run(['vlib', work], check=True, stdout=subprocess.DEVNULL)
print('== vlog (compile the chip + testbench)')
r = covhook.run(['vlog', '-work', work, '-sv', '-timescale', '1ns/1ps', '-f', 'neumann_soc.f',
                 'TEST/Test_hello/tb/tb_hello.sv'], stdout=open(B + '/vlog.log', 'w'), stderr=subprocess.STDOUT)
if r.returncode != 0:
    print(open(B + '/vlog.log').read()[-2000:])
    sys.exit('vlog failed, see ' + B + '/vlog.log')

args = ['-lib', work, '-GCLK_GATING=%d' % a.cg, 'tb_hello']
print('== vsim (run the test, CLK_GATING=%d)' % a.cg)
if a.gui:
    covhook.run(['vsim', '-voptargs=+acc'] + args + ['-do',
                 'add wave /tb_hello/clk /tb_hello/rst_n /tb_hello/dut/u_core/instr_addr_o '
                 '/tb_hello/dut/u_core/data_addr_o /tb_hello/dut/u_core/data_wdata_o '
                 '/tb_hello/dut/u_core/data_we_o; run -all'])
    sys.exit(0)
log = B + '/questa.log'
covhook.run(['vsim', '-c'] + args + ['-do', 'run -all; quit -f'],
            stdout=open(log, 'w'), stderr=subprocess.STDOUT)
text = open(log).read()
for line in text.splitlines():
    if 'step ' in line or 'RESULT' in line:
        print('   ' + line.lstrip('# '))
ok = 'RESULT: PASS' in text
print('PASSED %d / 1' % ok)
sys.exit(0 if ok else 1)
