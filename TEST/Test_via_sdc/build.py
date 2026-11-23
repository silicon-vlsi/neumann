#!/usr/bin/env python3
"""build.py - build the boot ROM and the gcd program, make the SPI flash images.

usage:  python build.py

Works on Windows (PowerShell / cmd) and Linux. Output in build/:
  rom.hex                 boot ROM (also copied to ../../sw/boot/rom.hex)
  gcd.elf, gcd.dis        program + disassembly
  flash_gcd.hex           good flash image
  flash_bad_magic.hex, flash_bad_length.hex, flash_bad_checksum.hex   negative tests
Toolchain: the first one found of riscv64-unknown-elf-gcc, riscv32-unknown-elf-gcc,
riscv-none-elf-gcc, clang (+ ld.lld, llvm-objcopy). If none is found, the ready-made
images from prebuilt/ are copied to build/ (enough to run the simulation).
"""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
B = os.path.join(HERE, 'build')
PY = sys.executable
ARCH = ['-march=rv32ic_zicsr', '-mabi=ilp32']
CFLAGS = ['-O2', '-ffreestanding', '-fno-builtin', '-nostdlib', '-Wall',
          '-I' + os.path.join(ROOT, 'sw', 'app'), '-I' + os.path.join(HERE, 'programs')]
IMAGES = ['rom.hex', 'flash_gcd.hex', 'flash_bad_magic.hex',
          'flash_bad_length.hex', 'flash_bad_checksum.hex']


def run(cmd):
    print('  ' + ' '.join(cmd))
    subprocess.run(cmd, check=True)


def find_toolchain():
    for p in ('riscv64-unknown-elf-', 'riscv32-unknown-elf-', 'riscv-none-elf-'):
        if shutil.which(p + 'gcc'):
            cc = [p + 'gcc'] + ARCH
            def link(lds, objs, out, p=p):
                run([p + 'gcc'] + ARCH + ['-nostdlib', '-nostartfiles', '-Wl,--no-relax',
                                          '-T', lds] + objs + ['-o', out])
            return 'GCC (' + p + 'gcc)', cc, link, p + 'objcopy', p + 'objdump'
    if shutil.which('clang') and shutil.which('ld.lld') and shutil.which('llvm-objcopy'):
        cc = ['clang', '--target=riscv32-unknown-elf'] + ARCH + ['-mno-relax']
        def link(lds, objs, out):
            run(['ld.lld', '-T', lds] + objs + ['-o', out])
        return 'clang/lld', cc, link, 'llvm-objcopy', 'llvm-objdump'
    return None


def p(*parts):
    return os.path.join(B, *parts)


def main():
    os.makedirs(B, exist_ok=True)
    print('== gcd inputs + golden')
    run([PY, os.path.join(HERE, 'programs', 'gen_gcd.py')])

    tc = find_toolchain()
    if tc is None:
        print('== no RISC-V compiler found: using prebuilt/ images')
        for f in IMAGES + ['gcd.dis']:
            shutil.copy(os.path.join(HERE, 'prebuilt', f), p(f))
        print('done (prebuilt). To rebuild from source install riscv64-unknown-elf-gcc '
              'or run build.py inside the Docker.')
        return
    name, cc, link, objcopy, objdump = tc
    print('== toolchain: ' + name)

    print('== boot ROM')
    run(cc + ['-c', os.path.join(ROOT, 'sw', 'boot', 'rom.S'), '-o', p('rom.o')])
    link(os.path.join(ROOT, 'sw', 'boot', 'link_rom.ld'), [p('rom.o')], p('rom.elf'))
    run([objcopy, '-O', 'binary', p('rom.elf'), p('rom.bin')])
    run([PY, os.path.join(ROOT, 'sw', 'bin2hex.py'), p('rom.bin'), p('rom.hex')])
    shutil.copy(p('rom.hex'), os.path.join(ROOT, 'sw', 'boot', 'rom.hex'))

    print('== gcd program')
    run(cc + ['-c', os.path.join(ROOT, 'sw', 'app', 'start.S'), '-o', p('start.o')])
    run(cc + CFLAGS + ['-c', os.path.join(HERE, 'programs', 'gcd.c'), '-o', p('gcd.o')])
    link(os.path.join(ROOT, 'sw', 'app', 'link_app.ld'), [p('start.o'), p('gcd.o')], p('gcd.elf'))
    with open(p('gcd.dis'), 'w') as f:
        subprocess.run([objdump, '-d', p('gcd.elf')], check=True, stdout=f)
    run([objcopy, '-O', 'binary', '--only-section=.vectors', '--only-section=.text',
         p('gcd.elf'), p('gcd_iram.bin')])
    run([objcopy, '-O', 'binary', '--only-section=.data', p('gcd.elf'), p('gcd_dram.bin')])

    print('== flash images')
    mk = [PY, os.path.join(HERE, 'tools', 'mkflash.py'), p('gcd_iram.bin'), p('gcd_dram.bin')]
    run(mk + [p('flash_gcd.hex')])
    for c in ('magic', 'length', 'checksum'):
        run(mk + [p('flash_bad_%s.hex' % c), '--corrupt', c])
    print('done')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit('build failed: %s' % e)
