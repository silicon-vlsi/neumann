#!/usr/bin/env python3
"""run_questa.py - build, then simulate the SDC flash boot with Questa.

usage:  python run_questa.py                 all 4 tests, batch mode
        python run_questa.py pass            one test: pass | e1 | e2 | e3
        python run_questa.py pass --gui      Questa GUI with waves
        python run_questa.py --no-build      skip build.py (use existing build/)
Needs vlib / vlog / vsim on PATH. Logs: build/questa_<test>.log
"""
import argparse, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
T = 'TEST/Test_via_sdc'            # paths below are relative to ROOT (neumann_soc/)
B = T + '/build'
TESTS = {'pass': 'flash_gcd', 'e1': 'flash_bad_magic',
         'e2': 'flash_bad_length', 'e3': 'flash_bad_checksum'}
KEYS = ('BOOT_STATUS', 'program done', 'MISMATCH', 'ERROR', 'tb_sdc_boot', 'RESULT')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('tests', nargs='*', help='pass e1 e2 e3 (default: all)')
    ap.add_argument('--gui', action='store_true')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    tests = a.tests or list(TESTS)
    bad = [t for t in tests if t not in TESTS]
    if bad:
        sys.exit('unknown test %s, use: pass e1 e2 e3' % bad)

    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')], check=True)
    os.chdir(ROOT)
    work = B + '/work'
    subprocess.run(['vlib', work], check=True)
    print('== vlog')
    with open(B + '/vlog.log', 'w') as log:
        r = covhook.run(['vlog', '-work', work, '-sv', '-timescale', '1ns/1ps',
                            '-f', 'neumann_soc.f',
                            T + '/flash/spiflash.v', T + '/tb/tb_sdc_boot.sv'],
                           stdout=log, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        print(open(B + '/vlog.log').read()[-3000:])
        sys.exit('vlog failed, see ' + B + '/vlog.log')

    passed = 0
    for t in tests:
        args = ['+EXPECT=' + t, '+firmware=%s/%s.hex' % (B, TESTS[t]),
                '+ROM=%s/rom.hex' % B, '+GOLDEN=%s/golden/gcd.golden' % T]
        print('== vsim %s (%s.hex)' % (t, TESTS[t]))
        if a.gui:
            covhook.run(['vsim', '-lib', work, '-voptargs=+acc', 'tb_sdc_boot',
                            '-do', 'add wave -r /tb_sdc_boot/*; run -all'] + args)
            continue
        logf = '%s/questa_%s.log' % (B, t)
        with open(logf, 'w') as log:
            covhook.run(['vsim', '-c', '-lib', work, '-voptargs=+acc', 'tb_sdc_boot',
                            '-do', 'run -all; quit -f'] + args,
                           stdout=log, stderr=subprocess.STDOUT)
        text = open(logf).read()
        for line in text.splitlines():
            if any(k in line for k in KEYS):
                print('   ' + line.lstrip('# '))
        if 'RESULT: PASS' in text:
            passed += 1
    if not a.gui:
        print('PASSED %d / %d' % (passed, len(tests)))
        sys.exit(0 if passed == len(tests) else 1)


if __name__ == '__main__':
    main()
