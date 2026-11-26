"""tests.py - test list shared by run_questa.py and run_verilator.py."""
T = 'verification/soc_level/Test_boot_programs'          # paths relative to neumann_soc/ (simulator runs there)
B = T + '/build'
PROGRAMS = ['gcd', 'sort', 'crc32', 'sieve', 'mathx', 'rtos']
BOOTS = ['sdc', 'dbg']
KEYS = ('BOOT_STATUS', 'debug boot', 'program done', 'MISMATCH', 'ERROR', 'checked', 'tb_boot', 'RESULT')
SOURCES = ['verification/soc_level/Test_via_sdc/flash/spiflash.v', T + '/tb/tb_boot.sv']


def plusargs(prog, boot):
    a = ['+BOOT=' + boot, '+NAME=' + prog, '+ROM=%s/rom.hex' % B,
         '+MAXCYC=%d' % (2000000 if boot == 'sdc' else 8000000),
         '+GOLDEN=%s/golden/%s.golden' % (T, prog)]
    if boot == 'sdc':
        a.append('+firmware=%s/flash_%s.hex' % (B, prog))
    else:
        a += ['+IRAM=%s/%s_iram.hex' % (B, prog), '+DRAM=%s/%s_dram.hex' % (B, prog)]
    return a


def select(progs, boots):
    p = progs or PROGRAMS
    b = boots or BOOTS
    bad = [x for x in p if x not in PROGRAMS] + [x for x in b if x not in BOOTS]
    if bad:
        raise SystemExit('unknown %s; programs: %s; boots: %s' % (bad, ' '.join(PROGRAMS), ' '.join(BOOTS)))
    return [(x, y) for x in p for y in b]


def show(text):
    for line in text.splitlines():
        line = line.lstrip('# ')
        if any(k in line for k in KEYS) and not line.startswith('- '):
            print('   ' + line)
