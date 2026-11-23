#!/usr/bin/env python3
"""run_questa.py - build, then run riscv-arch-test (rv32i I, C, Zifencei) with Questa.

usage:  python run_questa.py                     all tests, CLK_GATING=1
        python run_questa.py I                   one suite (I, C, Zifencei) or test names
        python run_questa.py add-01 --gui        GUI with waves (one test)
        python run_questa.py --cg 0              CLK_GATING=0
        python run_questa.py --no-build          reuse build/
Two libraries are compiled: build/work_std (chip memory map) and build/work_big (test-only
2 MB IRAM window, config_big/), the second only if a selected test needs it.
Needs vlib / vlog / vsim on PATH (Windows or Linux). No RISC-V compiler needed: build.py
copies prebuilt/. Logs: build/questa_<id>.log, report: build/report_questa.txt
"""
import argparse, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tests
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook

ROOT, B, T = tests.ROOT, tests.B, tests.T


def compile_lib(kind):
    # relative to neumann_soc/: an absolute Windows path (C:\...) in -lib breaks vopt
    # ("No module name found": it reads the drive colon as lib.module)
    work = '%s/build/work_%s' % (T, kind)
    m = tests.MAPS[kind]
    subprocess.run(['vlib', work], check=True, stdout=subprocess.DEVNULL)
    inc = ['+incdir+' + m['incdir']] if m['incdir'] else []
    print('== vlog (%s map)' % kind)
    logf = '%s/vlog_%s.log' % (B, kind)
    with open(logf, 'w') as log:
        r = covhook.run(['vlog', '-work', work, '-sv', '-timescale', '1ns/1ps'] + inc +
                           ['-f', 'neumann_soc.f', T + '/tb/tb_arch.sv'], stdout=log, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        print(open(logf).read()[-3000:])
        sys.exit('vlog failed, see ' + logf)
    return work


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('tests', nargs='*')
    ap.add_argument('--cg', type=int, default=1, choices=[0, 1])
    ap.add_argument('--gui', action='store_true')
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
    libs = {k: compile_lib(k) for k in sorted({maps[tests.tid(*t)] for t in sel})}
    results = []
    for t in sel:
        tid = tests.tid(*t)
        kind = maps[tid]
        gen = ['-GCLK_GATING=%d' % a.cg, '-GIRAM_PHYS=%d' % tests.MAPS[kind]['iram_phys']]
        if a.gui:
            covhook.run(['vsim', '-lib', libs[kind], '-voptargs=+acc'] + gen +
                           ['tb_arch', '-do', 'add wave -r /tb_arch/*; run -all'] + tests.plusargs(*t))
            continue
        sig = os.path.join(B, tid + '.signature')
        if os.path.exists(sig):
            os.remove(sig)
        logf = '%s/questa_%s.log' % (B, tid)
        t0 = time.time()
        with open(logf, 'w') as log:
            covhook.run(['vsim', '-c', '-lib', libs[kind]] + gen +
                           ['tb_arch', '-do', 'run -all; quit -f'] + tests.plusargs(*t),
                           stdout=log, stderr=subprocess.STDOUT)
        ok, msg = tests.check(*t)
        print('  %-24s %-4s %s  (%.0f s)' % (tid, 'PASS' if ok else 'FAIL', msg, time.time() - t0))
        results.append((tid, ok, msg))
    if a.gui:
        return
    failed = [n for n, ok, _ in results if not ok]
    with open(os.path.join(B, 'report_questa.txt'), 'w') as f:
        for n, ok, msg in results:
            f.write('%-24s %s  %s\n' % (n, 'PASS' if ok else 'FAIL', msg))
    print('PASSED %d / %d (CLK_GATING=%d)%s' % (len(results) - len(failed), len(results), a.cg,
                                               ('   FAILED: ' + ' '.join(failed)) if failed else ''))
    sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
