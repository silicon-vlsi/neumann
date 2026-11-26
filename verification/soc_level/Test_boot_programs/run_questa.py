#!/usr/bin/env python3
"""run_questa.py - build, then boot every test program with Questa, both boot ways.

usage:  python run_questa.py                         all 6 programs x {sdc, dbg} = 12 runs
        python run_questa.py -p rtos gcd -b sdc       some programs / boot ways
        python run_questa.py -p rtos -b dbg --gui     GUI with waves
        python run_questa.py --no-build               reuse build/
Programs: gcd sort crc32 sieve mathx rtos.  Boots: sdc (SPI flash on SDC) dbg (debug UART).
Needs vlib / vlog / vsim on PATH. Logs: build/questa_<program>_<boot>.log
Debug-UART boot is slow (~1600 clocks per word): rtos (~2400 words) needs ~4 M cycles.
"""
import argparse, os, subprocess, sys, time

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
    ap.add_argument('--gui', action='store_true')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    runs = tests.select(a.programs, a.boots)
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')], check=True)
    os.chdir(ROOT)
    B = tests.B
    work = B + '/work'
    subprocess.run([covhook.tool('vlib'), work], check=True)
    print('== vlog')
    with open(B + '/vlog.log', 'w') as log:
        r = covhook.run(['vlog', '-work', work, '-sv', '-timescale', '1ns/1ps', '-f', 'neumann_soc.f']
                           + tests.SOURCES, stdout=log, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        print(open(B + '/vlog.log').read()[-3000:])
        sys.exit('vlog failed, see ' + B + '/vlog.log')
    passed, failed = 0, []
    for prog, boot in runs:
        args = tests.plusargs(prog, boot)
        print('== %s via %s' % (prog, boot))
        if a.gui:
            covhook.run(['vsim', '-lib', work, '-voptargs=+acc', 'tb_boot',
                            '-do', 'add wave -r /tb_boot/*; run -all'] + args)
            continue
        logf = '%s/questa_%s_%s.log' % (B, prog, boot)
        t0 = time.time()
        with open(logf, 'w') as log:
            covhook.run(['vsim', '-c', '-lib', work, '-voptargs=+acc', 'tb_boot',
                            '-do', 'run -all; quit -f'] + args, stdout=log, stderr=subprocess.STDOUT)
        text = open(logf).read()
        tests.show(text)
        print('   (%.0f s)' % (time.time() - t0))
        if 'RESULT: PASS' in text:
            passed += 1
        else:
            failed.append('%s/%s' % (prog, boot))
    if not a.gui:
        print('PASSED %d / %d%s' % (passed, len(runs), ('   FAILED: ' + ' '.join(failed)) if failed else ''))
        sys.exit(0 if not failed else 1)


if __name__ == '__main__':
    main()
