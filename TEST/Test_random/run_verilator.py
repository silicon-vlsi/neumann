#!/usr/bin/env python3
"""run_verilator.py - build, then run the random-instruction programs with Verilator 5 and
compare each signature with the Spike golden (golden/<p>.sig, made by run_spike.py).

usage:  python3 run_verilator.py              rand_1 .. rand_10, CLK_GATING 1 and 0
        python3 run_verilator.py --quick      CLK_GATING 1 only
        python3 run_verilator.py 3 7          some seeds
        python3 run_verilator.py --no-build   reuse build/
Linux / Docker. Logs: build/sim_cg<g>_<p>.log
"""
import argparse, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tests
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook

ROOT, B, T = tests.ROOT, tests.B, tests.T


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('seeds', nargs='*')
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    progs = tests.names(a.seeds)
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')] + a.seeds, check=True)
    os.chdir(ROOT)
    results = []
    for cg in ([1] if a.quick else [1, 0]):
        obj = '%s/obj_cg%d' % (B, cg)
        print('== verilator build, CLK_GATING=%d' % cg)
        with open(obj + '.log', 'w') as log:
            r = covhook.run(['verilator', '--binary', '--timing', '-Wno-fatal', '-Wno-lint', '-Wno-style',
                                '-Wno-MULTIDRIVEN', '-GCLK_GATING=%d' % cg, '--timescale', '1ns/1ps',
                                '--top-module', 'tb_random', '-f', 'neumann_soc.f', T + '/tb/tb_random.sv',
                                os.path.join(ROOT, T, 'tb', 'dpi_getenv.c'), '--Mdir', obj, '-o', 'sim', '-j', '0'],
                               stdout=log, stderr=subprocess.STDOUT)
        if r.returncode != 0:
            print('\n'.join([l for l in open(obj + '.log').read().splitlines() if '%Error' in l][:10]))
            sys.exit('verilator failed, see ' + obj + '.log')
        for p in progs:
            sig = os.path.join(B, p + '.signature')
            if os.path.exists(sig):
                os.remove(sig)
            out = covhook.run([obj + '/sim'] + tests.plusargs(p), capture_output=True, text=True).stdout
            open('%s/sim_cg%d_%s.log' % (B, cg, p), 'w').write(out)
            ok, msg = tests.check(p)
            cyc = [l for l in out.splitlines() if 'done at cycle' in l]
            print('  %-8s cg%d %-4s %s%s' % (p, cg, 'PASS' if ok else 'FAIL', msg,
                                           ('  (' + cyc[0].split('done at ')[1].split(',')[0] + ')') if cyc else ''))
            results.append(('%s/cg%d' % (p, cg), ok))
    failed = [n for n, ok in results if not ok]
    print('PASSED %d / %d%s' % (len(results) - len(failed), len(results),
                                ('   FAILED: ' + ' '.join(failed)) if failed else ''))
    sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
