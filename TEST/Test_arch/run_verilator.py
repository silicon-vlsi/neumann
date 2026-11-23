#!/usr/bin/env python3
"""run_verilator.py - build, then run riscv-arch-test (rv32i I, C, Zifencei) with Verilator 5.

usage:  python run_verilator.py                  all 66 tests, CLK_GATING 1 and 0
        python run_verilator.py --quick          CLK_GATING 1 only
        python run_verilator.py I                one suite (I, C, Zifencei) or test names
        python run_verilator.py -j 8             8 simulations in parallel
        python run_verilator.py --no-build       reuse build/
Two simulators are built per CLK_GATING value: std (chip memory map) and big (test-only
2 MB IRAM window, config_big/). Logs: build/sim_cg<g>_<id>.log, report: build/report.txt
Linux / Docker (Verilator needs make + g++).
"""
import argparse, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tests
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook

ROOT, B, T = tests.ROOT, tests.B, tests.T


def build_sim(cg, kind):
    obj = '%s/obj_cg%d_%s' % (B, cg, kind)
    m = tests.MAPS[kind]
    inc = ['+incdir+' + m['incdir']] if m['incdir'] else []
    print('== verilator build, CLK_GATING=%d, %s map' % (cg, kind))
    with open(obj + '.log', 'w') as log:
        r = covhook.run(['verilator', '--binary', '--timing', '-Wno-fatal', '-Wno-lint', '-Wno-style',
                            '-Wno-MULTIDRIVEN', '-GCLK_GATING=%d' % cg, '-GIRAM_PHYS=%d' % m['iram_phys'],
                            '--timescale', '1ns/1ps', '--top-module', 'tb_arch'] + inc +
                           ['-f', 'neumann_soc.f', T + '/tb/tb_arch.sv',
                            os.path.join(ROOT, T, 'tb', 'dpi_getenv.c'), '--Mdir', obj, '-o', 'sim', '-j', '0'],
                           stdout=log, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        print('\n'.join([l for l in open(obj + '.log').read().splitlines() if '%Error' in l][:10]))
        sys.exit('verilator failed, see ' + obj + '.log')
    return obj + '/sim'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('tests', nargs='*')
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('-j', '--jobs', type=int, default=os.cpu_count() or 1)
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    sel = tests.select(a.tests)
    for t in [t for t in sel if tests.tid(*t) in tests.SKIP]:
        print('  %-24s SKIP %s' % (tests.tid(*t), tests.SKIP[tests.tid(*t)]))
    sel = [t for t in sel if tests.tid(*t) not in tests.SKIP]
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')] + a.tests, check=True)
    maps = tests.read_maps()
    os.chdir(ROOT)
    results = []
    for cg in ([1] if a.quick else [1, 0]):
        kinds = sorted({maps[tests.tid(*t)] for t in sel})
        sims = {k: build_sim(cg, k) for k in kinds}

        def one(t, cg=cg):
            tid = tests.tid(*t)
            sig = os.path.join(B, tid + '.signature')
            if os.path.exists(sig):
                os.remove(sig)
            out = covhook.run([sims[maps[tid]]] + tests.plusargs(*t), capture_output=True, text=True).stdout
            open('%s/sim_cg%d_%s.log' % (B, cg, tid), 'w').write(out)
            ok, msg = tests.check(*t)
            return tid, ok, msg

        with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
            for tid, ok, msg in ex.map(one, sel):
                print('  %-24s cg%d %-4s %s' % (tid, cg, 'PASS' if ok else 'FAIL', msg))
                results.append(('%s/cg%d' % (tid, cg), ok, msg))
    failed = [n for n, ok, _ in results if not ok]
    with open(os.path.join(B, 'report.txt'), 'w') as f:
        for n, ok, msg in results:
            f.write('%-28s %s  %s\n' % (n, 'PASS' if ok else 'FAIL', msg))
    print('PASSED %d / %d%s' % (len(results) - len(failed), len(results),
                                ('   FAILED: ' + ' '.join(failed)) if failed else ''))
    sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
