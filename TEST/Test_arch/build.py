#!/usr/bin/env python3
"""build.py - build the boot ROM and the riscv-arch-test programs (rv32i I, C, Zifencei).

usage:  python build.py              all 66 tests
        python build.py I            one suite (I, C, Zifencei)
        python build.py add-01 c.lw-01

For each test <id> (= <suite>-<name>, e.g. I-add-01), in build/:
  <id>.elf, <id>.dis           program + disassembly
  <id>_iram.hex                32-bit words from 0x8000_0000 (entry 0x8000_0080)
  <id>_dram.hex                32-bit words from DRAM base + 0x40 (.data, holds the signature)
  manifest.txt                 '<id> std|big': memory map the test was linked for
  rom.hex                      boot ROM (same source as sw/boot/rom.S)
Each test is linked for the chip memory map (std: IRAM 16 KB, DRAM 8 KB). If it does
not fit (far-branch / jal tests, 160 KB - 1.7 MB of code) it is linked for the test-only
big map (IRAM window 2 MB, DRAM at 0x8020_0000, see config_big/config.vh).
Toolchain: first found of riscv64-unknown-elf-gcc, riscv32-unknown-elf-gcc, riscv-none-elf-gcc,
clang (+ ld.lld, llvm-objcopy, llvm-objdump). None found -> prebuilt/ is copied to build/.
"""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tests

ROOT, B = tests.ROOT, tests.B
PY = sys.executable
ENV = os.path.join(HERE, 'env')
SUITE_ENV = os.path.join(tests.SUITE, 'env')


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def find_toolchain():
    for p in ('riscv64-unknown-elf-', 'riscv32-unknown-elf-', 'riscv-none-elf-'):
        if shutil.which(p + 'gcc'):
            def cc(march, args, p=p):
                return [p + 'gcc', '-march=' + march, '-mabi=ilp32', '-nostdlib', '-nostartfiles',
                        '-static', '-Wl,--no-relax'] + args
            return 'GCC (%sgcc)' % p, cc, p + 'objcopy', p + 'objdump'
    if all(shutil.which(t) for t in ('clang', 'ld.lld', 'llvm-objcopy', 'llvm-objdump')):
        def cc(march, args):
            return ['clang', '--target=riscv32-unknown-elf', '-march=' + march, '-mabi=ilp32',
                    '-mno-relax', '-nostdlib', '-static', '-fuse-ld=lld'] + args
        return 'clang/lld', cc, 'llvm-objcopy', 'llvm-objdump'
    return None


def b(*parts):
    return os.path.join(B, *parts)


def link_script(kind):
    m = tests.MAPS[kind]
    path = b('link_%s.ld' % kind)
    with open(path, 'w') as f:
        f.write('OUTPUT_ARCH("riscv")\nENTRY(rvtest_entry_point)\n'
                'MEMORY {\n  IRAM (rx) : ORIGIN = 0x80000000, LENGTH = %d\n'
                '  DRAM (rw) : ORIGIN = 0x%08X, LENGTH = %d\n}\n'
                'SECTIONS {\n'
                '  .text 0x80000080 : { *(.text.init) *(.text .text.*) } > IRAM\n'
                '  .data : { *(.data .data.* .sdata .sdata.* .tohost) } > DRAM\n'
                '  .bss  : { *(.bss .bss.* .sbss .sbss.* COMMON) } > DRAM\n'
                '  /DISCARD/ : { *(.riscv.attributes) *(.comment) }\n}\n'
                % (m['iram_len'], m['dram_base'] + 0x40, m['dram_len'] - 0x40))
    return path


def bin2hex(binf, hexf, pad=0):
    data = b'\0' * pad + open(binf, 'rb').read()
    data += b'\0' * (-len(data) % 4)
    with open(hexf, 'w') as f:
        for i in range(0, len(data), 4):
            f.write('%08x\n' % int.from_bytes(data[i:i + 4], 'little'))


def main():
    sel = tests.select(sys.argv[1:])
    os.makedirs(B, exist_ok=True)
    tc = find_toolchain()
    if tc is None:
        print('no RISC-V compiler found: copying prebuilt/ to build/')
        for f in os.listdir(os.path.join(HERE, 'prebuilt')):
            shutil.copyfile(os.path.join(HERE, 'prebuilt', f), b(f))
        return
    name, cc, objcopy, objdump = tc
    print('toolchain: ' + name)

    # boot ROM (direct boot jumps to 0x8000_0080)
    run(cc('rv32ic_zicsr', ['-T', os.path.join(ROOT, 'sw', 'boot', 'link_rom.ld'),
                            os.path.join(ROOT, 'sw', 'boot', 'rom.S'), '-o', b('rom.elf')]))
    run([objcopy, '-O', 'binary', b('rom.elf'), b('rom.bin')])
    bin2hex(b('rom.bin'), b('rom.hex'))

    lds = {k: link_script(k) for k in tests.MAPS}
    manifest = {}
    if os.path.exists(b('manifest.txt')):
        manifest = tests.read_maps()
    failed = []
    for suite, tname in sel:
        t = tests.tid(suite, tname)
        src = os.path.join(tests.SUITE, 'rv32i_m', suite, 'src', tname + '.S')
        used = None
        for kind in ('std', 'big'):
            args = ['-DXLEN=32', '-DTEST_CASE_1=True', '-DSIGBASE=0x%08X' % tests.MAPS[kind]['dram_base'],
                    '-I' + ENV, '-I' + SUITE_ENV, '-T', lds[kind], src, '-o', b(t + '.elf')]
            r = subprocess.run(cc(tests.SUITES[suite], args), capture_output=True, text=True)
            if r.returncode == 0:
                used = kind
                break
        if used is None:
            print('  %-24s BUILD FAILED: %s' % (t, (r.stderr.strip().splitlines() or ['?'])[-1]))
            failed.append(t)
            continue
        run([objcopy, '-O', 'binary', '--only-section=.text', b(t + '.elf'), b(t + '_iram.bin')])
        run([objcopy, '-O', 'binary', '--only-section=.data', b(t + '.elf'), b(t + '_dram.bin')])
        bin2hex(b(t + '_iram.bin'), b(t + '_iram.hex'), pad=0x80)
        bin2hex(b(t + '_dram.bin'), b(t + '_dram.hex'))
        with open(b(t + '.dis'), 'w') as f:
            run([objdump, '-d', b(t + '.elf')], stdout=f)
        for x in ('_iram.bin', '_dram.bin'):
            os.remove(b(t + x))
        manifest[t] = used
        print('  %-24s %s  IRAM %7d B  DRAM %5d B' % (
            t, used, os.path.getsize(b(t + '_iram.hex')) // 9 * 4, os.path.getsize(b(t + '_dram.hex')) // 9 * 4))
    with open(b('manifest.txt'), 'w') as f:
        for k in sorted(manifest):
            f.write('%s %s\n' % (k, manifest[k]))
    if failed:
        sys.exit('build failed: ' + ' '.join(failed))
    print('built %d tests (%d need the big map)' % (len(sel), sum(1 for s, n in sel if manifest[tests.tid(s, n)] == 'big')))


if __name__ == '__main__':
    main()
