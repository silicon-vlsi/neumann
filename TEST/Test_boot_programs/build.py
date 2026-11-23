#!/usr/bin/env python3
"""build.py - build the boot ROM and all test programs, make flash + debug-load images.

usage:  python build.py              all programs
        python build.py gcd rtos     only these

Programs: gcd sort crc32 sieve mathx rtos (FreeRTOS). For each <p>, in build/:
  <p>.elf, <p>.dis            program + disassembly
  <p>_iram.hex, <p>_dram.hex  32-bit words (debug-UART boot: WMEM to 0x8000_0000 / 0x8001_0040)
  flash_<p>.hex               SPI flash image (SDC boot), from ../Test_via_sdc/tools/mkflash.py
  rom.hex                     boot ROM (also copied to ../../sw/boot/rom.hex)
Toolchain: first found of riscv64-unknown-elf-gcc, riscv32-unknown-elf-gcc, riscv-none-elf-gcc,
clang (+ ld.lld, llvm-objcopy, llvm-nm). None found -> prebuilt/ is copied to build/.
"""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
PROG = os.path.join(HERE, 'programs')
RTOS = os.path.join(PROG, 'rtos')
FR = os.path.join(HERE, 'freertos')
B = os.path.join(HERE, 'build')
PY = sys.executable
ARCH = ['-march=rv32ic_zicsr', '-mabi=ilp32']
CFLAGS = ['-ffreestanding', '-fno-builtin', '-nostdlib', '-Wall', '-fno-common',
          '-ffunction-sections', '-I' + os.path.join(ROOT, 'sw', 'app'), '-I' + PROG]
FR_INC = ['-I' + RTOS, '-I' + os.path.join(RTOS, 'libc_inc'), '-I' + os.path.join(FR, 'include'), '-I' + os.path.join(FR, 'portable', 'RISC-V')]
START = os.path.join(ROOT, 'sw', 'app', 'start.S')
STUB = os.path.join(PROG, 'libc_stub.c')
# program -> (start file, C/asm sources, extra flags, optimisation)
PROGRAMS = {
    'gcd':   (START, [os.path.join(PROG, 'gcd.c')], [], '-O2'),
    'sort':  (START, [os.path.join(PROG, 'sort.c')], [], '-O2'),
    'crc32': (START, [os.path.join(PROG, 'crc32.c')], [], '-O2'),
    'sieve': (START, [os.path.join(PROG, 'sieve.c')], [], '-O2'),
    'mathx': (START, [os.path.join(PROG, 'mathx.c')], [], '-O2'),
    'rtos':  (os.path.join(RTOS, 'start_rtos.S'),
              [os.path.join(RTOS, 'rtos_test.c'), os.path.join(FR, 'tasks.c'),
               os.path.join(FR, 'list.c'), os.path.join(FR, 'queue.c'),
               os.path.join(FR, 'portable', 'MemMang', 'heap_1.c'),
               os.path.join(FR, 'portable', 'RISC-V', 'port.c'),
               os.path.join(FR, 'portable', 'RISC-V', 'portASM.S')], FR_INC, '-Os'),
}
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
    want = sys.argv[1:] or list(PROGRAMS)
    bad = [p for p in want if p not in PROGRAMS]
    if bad:
        sys.exit('unknown program %s, choose from %s' % (bad, ' '.join(PROGRAMS)))
    os.makedirs(B, exist_ok=True)
    run([PY, os.path.join(PROG, 'gen_golden.py')])

    tc = find_toolchain()
    if tc is None:
        print('no RISC-V compiler found: copying prebuilt/ to build/')
        for f in os.listdir(os.path.join(HERE, 'prebuilt')):
            shutil.copy(os.path.join(HERE, 'prebuilt', f), b(f))
        return
    name, cc, link, objcopy, objdump, nm, extra = tc
    print('toolchain: ' + name)

    # boot ROM
    run(cc + ['-c', os.path.join(ROOT, 'sw', 'boot', 'rom.S'), '-o', b('rom.o')])
    link(os.path.join(ROOT, 'sw', 'boot', 'link_rom.ld'), [b('rom.o')], b('rom.elf'))
    run([objcopy, '-O', 'binary', b('rom.elf'), b('rom.bin')])
    run([PY, os.path.join(ROOT, 'sw', 'bin2hex.py'), b('rom.bin'), b('rom.hex')])
    shutil.copy(b('rom.hex'), os.path.join(ROOT, 'sw', 'boot', 'rom.hex'))

    for p in want:
        start, srcs, flags, opt = PROGRAMS[p]
        objs = []
        for s in [start, STUB] + srcs:
            o = b('%s__%s.o' % (p, os.path.splitext(os.path.basename(s))[0]))
            run(cc + CFLAGS + extra + flags + [opt, '-c', s, '-o', o])
            objs.append(o)
        elf = b(p + '.elf')
        link(os.path.join(ROOT, 'sw', 'app', 'link_app.ld'), objs, elf)
        with open(b(p + '.dis'), 'w') as f:
            run([objdump, '-d', elf], stdout=f)
        run([objcopy, '-O', 'binary', '--only-section=.vectors', '--only-section=.text', elf, b(p + '_iram.bin')])
        run([objcopy, '-O', 'binary', '--only-section=.data', elf, b(p + '_dram.bin')])
        for part in ('iram', 'dram'):
            run([PY, os.path.join(ROOT, 'sw', 'bin2hex.py'), b('%s_%s.bin' % (p, part)), b('%s_%s.hex' % (p, part))])
        run([PY, os.path.join(HERE, '..', 'Test_via_sdc', 'tools', 'mkflash.py'),
             b(p + '_iram.bin'), b(p + '_dram.bin'), b('flash_%s.hex' % p)], stdout=subprocess.DEVNULL)
        sym = symbols(nm, elf)
        isz = os.path.getsize(b(p + '_iram.bin'))
        end = sym.get('__bss_end', 0)
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
