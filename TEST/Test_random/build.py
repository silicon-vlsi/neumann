#!/usr/bin/env python3
"""build.py - generate and build the random-instruction programs (and the boot ROM).

usage:  python build.py              rand_1 .. rand_10
        python build.py 3 7          only these seeds
        python build.py --rebuild    compile even if Spike goldens exist (run_spike.py does this)

When golden/ has Spike results, the images are pinned to them: build.py copies prebuilt/
(the exact images Spike ran) into build/ instead of compiling, so a different compiler on
another machine cannot silently change the programs. Use --rebuild only with run_spike.py.

For each program, in build/: rand_<n>.elf, .dis, _iram.hex (from 0x8000_0000),
_dram.hex (from 0x8001_0040); and rom.hex. The source programs/rand_<n>.S is made by
gen_random.py (same seed -> same program).
Toolchain: first found of riscv64-unknown-elf-gcc, riscv32-unknown-elf-gcc, riscv-none-elf-gcc,
clang (+ ld.lld, llvm-objcopy, llvm-objdump). None found -> prebuilt/ is copied to build/.
Images and Spike goldens belong together: after a rebuild run run_spike.py again
(it rebuilds, runs Spike and refreshes prebuilt/ and golden/ in one go).
"""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tests

ROOT, B = tests.ROOT, tests.B
PY = sys.executable
ARCH = ['-march=rv32ic_zicsr', '-mabi=ilp32']


def run(cmd, **kw):
    subprocess.run(cmd, check=True, **kw)


def find_toolchain():
    for p in ('riscv64-unknown-elf-', 'riscv32-unknown-elf-', 'riscv-none-elf-'):
        if shutil.which(p + 'gcc'):
            def cc(args, p=p):
                return [p + 'gcc'] + ARCH + ['-nostdlib', '-nostartfiles', '-static', '-Wl,--no-relax'] + args
            return 'GCC (%sgcc)' % p, cc, p + 'objcopy', p + 'objdump'
    if all(shutil.which(t) for t in ('clang', 'ld.lld', 'llvm-objcopy', 'llvm-objdump')):
        def cc(args):
            return ['clang', '--target=riscv32-unknown-elf'] + ARCH + ['-mno-relax', '-nostdlib', '-static',
                                                                    '-fuse-ld=lld'] + args
        return 'clang/lld', cc, 'llvm-objcopy', 'llvm-objdump'
    return None


def b(*p):
    return os.path.join(B, *p)


def main():
    args = [x for x in sys.argv[1:] if x != '--rebuild']
    rebuild = '--rebuild' in sys.argv[1:]
    progs = tests.names(args)
    os.makedirs(B, exist_ok=True)
    pre = os.path.join(HERE, 'prebuilt')

    def is_pinned(p):                          # a Spike golden exists for exactly these images
        return os.path.exists(os.path.join(tests.GOLD, p + '.md5')) and \
            os.path.exists(os.path.join(pre, p + '_iram.hex'))

    def copy_pre(names):
        for f in names:
            if os.path.exists(os.path.join(pre, f)):
                shutil.copyfile(os.path.join(pre, f), b(f))

    pinned = [p for p in progs if is_pinned(p) and not rebuild]
    todo = [p for p in progs if p not in pinned]
    if pinned:
        print('%d program(s) with Spike goldens: using their pinned images from prebuilt/' % len(pinned))
        copy_pre(['rom.hex'] + [p + x for p in pinned for x in ('_iram.hex', '_dram.hex', '.dis')])
    if not todo:
        return
    tc = find_toolchain()
    if tc is None:
        print('no RISC-V compiler found: copying prebuilt/ to build/ for the other %d program(s)' % len(todo))
        copy_pre(['rom.hex'] + [p + x for p in todo for x in ('_iram.hex', '_dram.hex', '.dis')])
        return
    progs = todo
    name, cc, objcopy, objdump = tc
    print('toolchain: ' + name)
    run(cc(['-T', os.path.join(ROOT, 'sw', 'boot', 'link_rom.ld'),
            os.path.join(ROOT, 'sw', 'boot', 'rom.S'), '-o', b('rom.elf')]))
    run([objcopy, '-O', 'binary', b('rom.elf'), b('rom.bin')])
    run([PY, os.path.join(ROOT, 'sw', 'bin2hex.py'), b('rom.bin'), b('rom.hex')])
    for p in progs:
        seed = int(p.split('_')[1])
        src = os.path.join(HERE, 'programs', p + '.S')
        run([PY, os.path.join(HERE, 'gen_random.py'), '--seed', str(seed), '--blocks', str(tests.BLOCKS),
             '--len', str(tests.LENGTH), '-o', src])
        run(cc(['-T', os.path.join(ROOT, 'sw', 'app', 'link_app.ld'), src, '-o', b(p + '.elf')]))
        with open(b(p + '.dis'), 'w') as f:
            run([objdump, '-d', b(p + '.elf')], stdout=f)
        run([objcopy, '-O', 'binary', '--only-section=.vectors', '--only-section=.text', b(p + '.elf'), b(p + '_iram.bin')])
        run([objcopy, '-O', 'binary', '--only-section=.data', b(p + '.elf'), b(p + '_dram.bin')])
        for part in ('iram', 'dram'):
            run([PY, os.path.join(ROOT, 'sw', 'bin2hex.py'), b('%s_%s.bin' % (p, part)), b('%s_%s.hex' % (p, part))])
        isz = os.path.getsize(b(p + '_iram.bin'))
        print('%-8s IRAM %5d B  DRAM %5d B' % (p, isz, os.path.getsize(b(p + '_dram.bin'))))
        if isz > 16384:
            sys.exit(p + ' does not fit IRAM')
    print('done')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit('build failed: %s' % e)
