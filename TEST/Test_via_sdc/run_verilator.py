#!/usr/bin/env python3
"""run_verilator.py - build, then simulate the SDC flash boot with Verilator 5.

usage:  python run_verilator.py            4 tests x CLK_GATING 1 and 0 (8 runs)
        python run_verilator.py --quick    CLK_GATING 1 only (4 runs)
        python run_verilator.py --no-build skip build.py
Linux / Docker (Verilator needs make + a C++ compiler). Logs: build/sim_cg<g>_<test>.log
"""
import argparse, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import covhook
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
T = 'TEST/Test_via_sdc'
B = T + '/build'
TESTS = {'pass': 'flash_gcd', 'e1': 'flash_bad_magic',
         'e2': 'flash_bad_length', 'e3': 'flash_bad_checksum'}
KEYS = ('BOOT_STATUS', 'program done', 'MISMATCH', 'ERROR', 'tb_sdc_boot', 'RESULT')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py')], check=True)
    os.chdir(ROOT)
    passed = total = 0
    for cg in ([1] if a.quick else [1, 0]):
        obj = '%s/obj_cg%d' % (B, cg)
        print('== verilator CLK_GATING=%d' % cg)
        with open(obj + '.log', 'w') as log:
            r = covhook.run(['verilator', '--binary', '--timing', '-Wno-fatal', '-Wno-lint',
                                '-Wno-style', '-Wno-MULTIDRIVEN', '-GCLK_GATING=%d' % cg,
                                '--timescale', '1ns/1ps', '--top-module', 'tb_sdc_boot',
                                '-f', 'neumann_soc.f', T + '/flash/spiflash.v',
                                T + '/tb/tb_sdc_boot.sv',
                                os.path.join(ROOT, T, 'tb', 'dpi_getenv.c'),
                                '--Mdir', obj, '-o', 'sim'],
                               stdout=log, stderr=subprocess.STDOUT)
        if r.returncode != 0:
            print('\n'.join([l for l in open(obj + '.log').read().splitlines() if '%Error' in l][:10]))
            sys.exit('verilator failed, see ' + obj + '.log')
        for t, img in TESTS.items():
            total += 1
            out = covhook.run([obj + '/sim', '+EXPECT=' + t, '+firmware=%s/%s.hex' % (B, img),
                                  '+ROM=%s/rom.hex' % B, '+GOLDEN=%s/golden/gcd.golden' % T],
                                 capture_output=True, text=True).stdout
            open('%s/sim_cg%d_%s.log' % (B, cg, t), 'w').write(out)
            for line in out.splitlines():
                if any(k in line for k in KEYS) and not line.startswith('- '):
                    print('   ' + line)
            if 'RESULT: PASS' in out:
                passed += 1
    print('PASSED %d / %d' % (passed, total))
    sys.exit(0 if passed == total else 1)


if __name__ == '__main__':
    main()
