#!/usr/bin/env python3
"""run_questa.py - build, then run the interrupt / peripheral tests with Questa.

usage:  python run_questa.py                  irq and periph, CLK_GATING=1
        python run_questa.py -p irq --gui     GUI with waves
        python run_questa.py --cg 0           CLK_GATING=0
        python run_questa.py --no-build       reuse build/
Needs vlib / vlog / vsim on PATH (Windows or Linux). No RISC-V compiler needed: build.py
copies prebuilt/. Logs: build/questa_<program>.log
"""
import argparse, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import tests
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-p', '--programs', nargs='*', default=[])
    ap.add_argument('--cg', type=int, default=1, choices=[0, 1])
    ap.add_argument('--gui', action='store_true')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    progs = tests.select(a.programs)
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')] + progs, check=True)
    os.chdir(ROOT)
    B = tests.B                       # relative path: an absolute C:\ path in -lib breaks vopt
    work = B + '/work'
    subprocess.run([covhook.tool('vlib'), work], check=True, stdout=subprocess.DEVNULL)
    print('== vlog')
    with open(B + '/vlog.log', 'w') as log:
        r = covhook.run(['vlog', '-work', work, '-sv', '-timescale', '1ns/1ps', '-f', 'neumann_soc.f']
                           + tests.SOURCES, stdout=log, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        print(open(B + '/vlog.log').read()[-3000:])
        sys.exit('vlog failed, see ' + B + '/vlog.log')
    passed, failed = 0, []
    for prog in progs:
        args = ['-GCLK_GATING=%d' % a.cg, 'tb_periph'] + tests.plusargs(prog)
        print('== %s (CLK_GATING=%d)' % (prog, a.cg))
        if a.gui:
            covhook.run(['vsim', '-lib', work, '-voptargs=+acc'] + args +
                           ['-do', 'add wave -r /tb_periph/*; run -all'])
            continue
        logf = '%s/questa_%s.log' % (B, prog)
        t0 = time.time()
        with open(logf, 'w') as log:
            covhook.run(['vsim', '-c', '-lib', work] + args + ['-do', 'run -all; quit -f'],
                           stdout=log, stderr=subprocess.STDOUT)
        text = open(logf).read()
        tests.show(text)
        print('   (%.0f s)' % (time.time() - t0))
        if 'RESULT: PASS' in text:
            passed += 1
        else:
            failed.append(prog)
    if not a.gui:
        print('PASSED %d / %d%s' % (passed, len(progs), ('   FAILED: ' + ' '.join(failed)) if failed else ''))
        sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
