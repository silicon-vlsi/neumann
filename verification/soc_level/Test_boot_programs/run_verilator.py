#!/usr/bin/env python3
"""run_verilator.py - build, then boot every test program with Verilator 5, both boot ways.

usage:  python run_verilator.py                      6 programs x {sdc, dbg} x CLK_GATING {1, 0}
        python run_verilator.py --quick              CLK_GATING 1 only (12 runs)
        python run_verilator.py -p rtos -b sdc dbg   some programs / boot ways
        python run_verilator.py -j 4                 4 simulations in parallel
        python run_verilator.py --no-build           reuse build/
Linux / Docker (Verilator needs make + g++). Logs: build/sim_cg<g>_<program>_<boot>.log
"""
import argparse, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)
import tests
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-p', '--programs', nargs='*', default=[])
    ap.add_argument('-b', '--boots', nargs='*', default=[])
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('-j', '--jobs', type=int, default=1)
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    runs = tests.select(a.programs, a.boots)
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')], check=True)
    os.chdir(ROOT)
    B = tests.B
    results = []
    for cg in ([1] if a.quick else [1, 0]):
        obj = '%s/obj_cg%d' % (B, cg)
        print('== verilator build, CLK_GATING=%d' % cg)
        with open(obj + '.log', 'w') as log:
            r = covhook.run(['verilator', '--binary', '--timing', '-Wno-fatal', '-Wno-lint', '-Wno-style',
                                '-Wno-MULTIDRIVEN', '-GCLK_GATING=%d' % cg, '--timescale', '1ns/1ps',
                                '--top-module', 'tb_boot', '-f', 'neumann_soc.f'] + tests.SOURCES +
                               [covhook.dpi_c(obj, os.path.join(ROOT, tests.T, 'tb', 'dpi_getenv.c')), '--Mdir', obj, '-o', 'sim',
                                '-j', '0'], stdout=log, stderr=subprocess.STDOUT)
        if r.returncode != 0:
            print('\n'.join([l for l in open(obj + '.log').read().splitlines() if '%Error' in l][:10]))
            sys.exit('verilator failed, see ' + obj + '.log')

        def one(run, cg=cg, obj=obj):
            prog, boot = run
            out = covhook.run([obj + '/sim'] + tests.plusargs(prog, boot),
                                 capture_output=True, text=True).stdout
            open('%s/sim_cg%d_%s_%s.log' % (B, cg, prog, boot), 'w').write(out)
            return prog, boot, out

        with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
            for prog, boot, out in ex.map(one, runs):
                print('== %s via %s (CLK_GATING=%d)' % (prog, boot, cg))
                tests.show(out)
                results.append(('%s/%s/cg%d' % (prog, boot, cg), 'RESULT: PASS' in out))
    failed = [n for n, ok in results if not ok]
    print('PASSED %d / %d%s' % (len(results) - len(failed), len(results),
                                ('   FAILED: ' + ' '.join(failed)) if failed else ''))
    sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
