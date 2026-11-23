#!/usr/bin/env python3
"""run_questa.py - build, then run the random-instruction programs with Questa and compare
each signature with the Spike golden (golden/<p>.sig, made by run_spike.py).

usage:  python run_questa.py                 rand_1 .. rand_10, CLK_GATING=1
        python run_questa.py --cg 0          CLK_GATING=0
        python run_questa.py 3 --gui         one seed with waves
        python run_questa.py --no-build      reuse build/
Needs vlib / vlog / vsim on PATH (Windows or Linux). No RISC-V compiler needed: build.py
copies prebuilt/. Logs: build/questa_<p>.log
"""
import argparse, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tests
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook

ROOT, B, T = tests.ROOT, tests.B, tests.T


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('seeds', nargs='*')
    ap.add_argument('--cg', type=int, default=1, choices=[0, 1])
    ap.add_argument('--gui', action='store_true')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    progs = tests.names(a.seeds)
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')] + a.seeds, check=True)
    os.chdir(ROOT)
    work = T + '/build/work'          # relative: an absolute C:\ path in -lib breaks vopt
    subprocess.run(['vlib', work], check=True, stdout=subprocess.DEVNULL)
    print('== vlog')
    logf = T + '/build/vlog.log'
    with open(logf, 'w') as log:
        r = covhook.run(['vlog', '-work', work, '-sv', '-timescale', '1ns/1ps', '-f', 'neumann_soc.f',
                            T + '/tb/tb_random.sv'], stdout=log, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        print(open(logf).read()[-3000:])
        sys.exit('vlog failed, see ' + logf)
    results = []
    for p in progs:
        gen = ['-GCLK_GATING=%d' % a.cg, 'tb_random'] + tests.plusargs(p)
        if a.gui:
            covhook.run(['vsim', '-lib', work, '-voptargs=+acc'] + gen + ['-do', 'add wave -r /tb_random/*; run -all'])
            continue
        sig = os.path.join(B, p + '.signature')
        if os.path.exists(sig):
            os.remove(sig)
        t0 = time.time()
        with open('%s/questa_%s.log' % (B, p), 'w') as log:
            covhook.run(['vsim', '-c', '-lib', work] + gen + ['-do', 'run -all; quit -f'],
                           stdout=log, stderr=subprocess.STDOUT)
        ok, msg = tests.check(p)
        print('  %-8s %-4s %s  (%.0f s)' % (p, 'PASS' if ok else 'FAIL', msg, time.time() - t0))
        results.append((p, ok))
    if a.gui:
        return
    failed = [n for n, ok in results if not ok]
    print('PASSED %d / %d (CLK_GATING=%d)%s' % (len(results) - len(failed), len(results), a.cg,
                                               ('   FAILED: ' + ' '.join(failed)) if failed else ''))
    sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
