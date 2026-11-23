#!/usr/bin/env python3
"""run_spike.py - make the Spike reference signatures (run this where Spike is installed,
e.g. inside the iic-osic-tools Docker container).

usage:  python3 run_spike.py                 build rand_1 .. rand_10, run Spike, save goldens
        python3 run_spike.py 3 7             some seeds
        python3 run_spike.py --spike /path/to/spike --isa rv32ic

For each program:  spike --isa=<isa> -m0x80000000:0x12000 +signature=golden/<p>.sig
                   +signature-granularity=4 build/<p>.elf
then golden/<p>.md5 (fingerprint of the images the golden belongs to) and the images are
copied to prebuilt/, so Questa / Verilator elsewhere (no compiler needed) use exactly the
images Spike ran. The program starts at 0x8000_0000 (j _start), exits by writing tohost.
"""
import argparse, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tests

B, GOLD = tests.B, tests.GOLD


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('seeds', nargs='*')
    ap.add_argument('--spike', default='spike')
    ap.add_argument('--isa', default='rv32ic')
    ap.add_argument('--no-build', action='store_true')
    a = ap.parse_args()
    progs = tests.names(a.seeds)
    if not shutil.which(a.spike) and not os.path.exists(a.spike):
        sys.exit('spike not found (use --spike <path>)')
    if not a.no_build:
        subprocess.run([sys.executable, os.path.join(HERE, 'build.py'), '--rebuild'] + a.seeds, check=True)
    os.makedirs(GOLD, exist_ok=True)
    pre = os.path.join(HERE, 'prebuilt')
    os.makedirs(pre, exist_ok=True)
    failed = []
    for p in progs:
        sig = os.path.join(GOLD, p + '.sig')
        if os.path.exists(sig):
            os.remove(sig)
        cmd = [a.spike, '--isa=' + a.isa, '-m0x80000000:0x12000', '+signature=' + sig,
               '+signature-granularity=4', os.path.join(B, p + '.elf')]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            msg = (r.stdout + r.stderr).strip().splitlines()
        except subprocess.TimeoutExpired:
            r, msg = None, ['timeout: program did not write tohost']
        if r is None or r.returncode != 0 or not os.path.exists(sig):
            print('  %-8s SPIKE FAILED: %s' % (p, ' | '.join(msg[-3:]) or 'no signature'))
            failed.append(p)
            continue
        with open(os.path.join(GOLD, p + '.md5'), 'w') as f:
            f.write(tests.image_md5(p) + '\n')
        for f in (p + '_iram.hex', p + '_dram.hex', p + '.dis', 'rom.hex'):
            shutil.copyfile(os.path.join(B, f), os.path.join(pre, f))
        n = sum(1 for l in open(sig) if l.strip())
        print('  %-8s golden/%s.sig: %d words' % (p, p, n))
    if failed:
        sys.exit('Spike failed for: ' + ' '.join(failed))
    print('goldens written to golden/, images copied to prebuilt/')


if __name__ == '__main__':
    main()
