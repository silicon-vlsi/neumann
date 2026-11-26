#!/usr/bin/env python3
"""run_verilator.py - build, then run the bus corner-case test with Verilator 5.

usage:  python run_verilator.py               bus x CLK_GATING {1, 0}
        python run_verilator.py --quick       CLK_GATING 1 only
        python run_verilator.py -p bus        some programs
        python run_verilator.py --no-build    reuse build/
Linux / Docker (Verilator needs make + g++). Logs: build/sim_cg<g>_<program>.log
"""
import argparse, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)
import tests
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-p', '--programs', nargs='*', default=[])
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    progs = tests.select(a.programs)
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')] + progs, check=True)
    os.chdir(ROOT)
    B = tests.B
    results = []
    for cg in ([1] if a.quick else [1, 0]):
        obj = '%s/obj_cg%d' % (B, cg)
        print('== verilator build, CLK_GATING=%d' % cg)
        with open(obj + '.log', 'w') as log:
            r = covhook.run(['verilator', '--binary', '--timing', '-Wno-fatal', '-Wno-lint', '-Wno-style',
                                '-Wno-MULTIDRIVEN', '-GCLK_GATING=%d' % cg, '--timescale', '1ns/1ps',
                                '--top-module', 'tb_bus', '-f', 'neumann_soc.f'] + tests.SOURCES +
                               [covhook.dpi_c(obj, os.path.join(ROOT, tests.T, 'tb', 'dpi_getenv.c')), '--Mdir', obj, '-o', 'sim',
                                '-j', '0'], stdout=log, stderr=subprocess.STDOUT)
        if r.returncode != 0:
            print('\n'.join([l for l in open(obj + '.log').read().splitlines() if '%Error' in l][:10]))
            sys.exit('verilator failed, see ' + obj + '.log')
        for prog in progs:
            out = covhook.run([obj + '/sim'] + tests.plusargs(prog), capture_output=True, text=True).stdout
            open('%s/sim_cg%d_%s.log' % (B, cg, prog), 'w').write(out)
            print('== %s (CLK_GATING=%d)' % (prog, cg))
            tests.show(out)
            results.append(('%s/cg%d' % (prog, cg), 'RESULT: PASS' in out))
    failed = [n for n, ok in results if not ok]
    print('PASSED %d / %d%s' % (len(results) - len(failed), len(results),
                                ('   FAILED: ' + ' '.join(failed)) if failed else ''))
    sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
