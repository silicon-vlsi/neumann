#!/usr/bin/env python3
"""build.py - build the boot ROM and the bus corner-case test program.

usage:  python build.py              the program (bus)
        python build.py bus          same

For each program <p>, in build/:  <p>.elf, <p>.dis, <p>_iram.hex (from 0x8000_0000),
<p>_dram.hex (from 0x8001_0040), and rom.hex. The testbench preloads them (direct boot).
Toolchain: first found of riscv64-unknown-elf-gcc, riscv32-unknown-elf-gcc, riscv-none-elf-gcc,
clang (+ ld.lld, llvm-objcopy, llvm-nm). None found -> prebuilt/ is copied to build/.
"""
import os, shutil, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import covhook
covhook.add_riscv_paths()          # finds the RISC-V compiler on any machine

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
PROG = os.path.join(HERE, 'programs')
B = os.path.join(HERE, 'build')
PY = sys.executable
sys.path.insert(0, HERE)
import tests

ARCH = ['-march=rv32ic_zicsr', '-mabi=ilp32']
CFLAGS = ['-ffreestanding', '-fno-builtin', '-nostdlib', '-Wall', '-fno-common', '-O2',
          '-ffunction-sections', '-I' + os.path.join(ROOT, 'sw', 'app'), '-I' + PROG]
START = os.path.join(ROOT, 'sw', 'app', 'start.S')
STUB = os.path.join(PROG, 'libc_stub.c')
IRAM_MAX, DATA_END = 16384, 0x80011BFC      # .data/.bss must end below RESULT_N


def run(cmd, **kw):
    subprocess.run(cmd, check=True, **kw)


def find_toolchain():
    for p in ('riscv64-unknown-elf-', 'riscv32-unknown-elf-', 'riscv-none-elf-'):
        if shutil.which(p + 'gcc'):
            cc = [p + 'gcc'] + ARCH
            def link(lds, objs, out, p=p):
                run([p + 'gcc'] + ARCH + ['-nostdlib', '-nostartfiles', '-Wl,--no-relax',
                                          '-Wl,--gc-sections', '-T', lds] + objs + ['-o', out])
            return 'GCC (%sgcc)' % p, cc, link, p + 'objcopy', p + 'objdump', p + 'nm', \
                   ['-fno-tree-loop-distribute-patterns']
    if all(shutil.which(t) for t in ('clang', 'ld.lld', 'llvm-objcopy', 'llvm-nm')):
        cc = ['clang', '--target=riscv32-unknown-elf'] + ARCH + ['-mno-relax']
        def link(lds, objs, out):
            run(['ld.lld', '--gc-sections', '-T', lds] + objs + ['-o', out])
        return 'clang/lld', cc, link, 'llvm-objcopy', 'llvm-objdump', 'llvm-nm', []
    return None


def b(*parts):
    return os.path.join(B, *parts)


def symbols(nm, elf):
    out = subprocess.run([nm, elf], check=True, capture_output=True, text=True).stdout
    return {l.split()[2]: int(l.split()[0], 16) for l in out.splitlines() if len(l.split()) == 3}


def main():
    want = tests.select(sys.argv[1:])
    os.makedirs(B, exist_ok=True)
    tc = find_toolchain()
    if tc is None:
        print('no RISC-V compiler found: copying prebuilt/ to build/')
        for f in os.listdir(os.path.join(HERE, 'prebuilt')):
            shutil.copyfile(os.path.join(HERE, 'prebuilt', f), b(f))
        return
    name, cc, link, objcopy, objdump, nm, extra = tc
    print('toolchain: ' + name)
    run(cc + ['-c', os.path.join(ROOT, 'sw', 'boot', 'rom.S'), '-o', b('rom.o')])
    link(os.path.join(ROOT, 'sw', 'boot', 'link_rom.ld'), [b('rom.o')], b('rom.elf'))
    run([objcopy, '-O', 'binary', b('rom.elf'), b('rom.bin')])
    run([PY, os.path.join(ROOT, 'sw', 'bin2hex.py'), b('rom.bin'), b('rom.hex')])
    for p in want:
        objs = []
        for s in [START, STUB, os.path.join(PROG, p + '.c')]:
            o = b('%s__%s.o' % (p, os.path.splitext(os.path.basename(s))[0]))
            run(cc + CFLAGS + extra + ['-c', s, '-o', o])
            objs.append(o)
        elf = b(p + '.elf')
        link(os.path.join(ROOT, 'sw', 'app', 'link_app.ld'), objs, elf)
        with open(b(p + '.dis'), 'w') as f:
            run([objdump, '-d', elf], stdout=f)
        run([objcopy, '-O', 'binary', '--only-section=.vectors', '--only-section=.text', elf, b(p + '_iram.bin')])
        run([objcopy, '-O', 'binary', '--only-section=.data', elf, b(p + '_dram.bin')])
        for part in ('iram', 'dram'):
            run([PY, os.path.join(ROOT, 'sw', 'bin2hex.py'), b('%s_%s.bin' % (p, part)), b('%s_%s.hex' % (p, part))])
        isz = os.path.getsize(b(p + '_iram.bin'))
        end = symbols(nm, elf).get('__bss_end', 0)
        print('%-6s IRAM %5d B   DRAM .data %4d B   data+bss end 0x%08x' % (
            p, isz, os.path.getsize(b(p + '_dram.bin')), end))
        if isz > IRAM_MAX or end > DATA_END:
            sys.exit('%s does not fit: IRAM max %d B, data+bss must end <= 0x%08x' % (p, IRAM_MAX, DATA_END))
    print('done')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit('build failed: %s' % e)
