#!/usr/bin/env python3
"""run_verilator.py - run Test_hello in Verilator (Linux / Docker).  python3 run_verilator.py [--cg 0]"""
import argparse, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook

ap = argparse.ArgumentParser()
ap.add_argument('--cg', type=int, default=1, choices=[0, 1])
a = ap.parse_args()
subprocess.run([sys.executable, os.path.join(HERE, 'programs', 'gen_golden.py')], check=True)
subprocess.run([sys.executable, os.path.join(HERE, 'programs', 'mkhex.py')], check=True,
               stdout=subprocess.DEVNULL)
os.chdir(ROOT)
obj = 'TEST/Test_hello/build/obj_cg%d' % a.cg
print('== verilator build (CLK_GATING=%d), takes a minute' % a.cg)
r = covhook.run(['verilator', '--binary', '--timing', '-Wno-fatal', '-Wno-lint', '-Wno-style',
                 '-Wno-MULTIDRIVEN', '-GCLK_GATING=%d' % a.cg, '--timescale', '1ns/1ps',
                 '--top-module', 'tb_hello', '-f', 'neumann_soc.f', 'TEST/Test_hello/tb/tb_hello.sv',
                 covhook.dpi_c(obj, os.path.join(ROOT, 'TEST', 'Test_hello', 'tb', 'dpi_getenv.c')),
                 '--Mdir', obj, '-o', 'sim', '-j', '0'],
                stdout=open(obj + '.log', 'w'), stderr=subprocess.STDOUT)
if r.returncode != 0:
    sys.exit('verilator failed, see ' + obj + '.log')
out = covhook.run([obj + '/sim'], capture_output=True, text=True).stdout
for line in out.splitlines():
    if 'step ' in line or 'RESULT' in line:
        print('   ' + line)
ok = 'RESULT: PASS' in out
print('PASSED %d / 1' % ok)
sys.exit(0 if ok else 1)
