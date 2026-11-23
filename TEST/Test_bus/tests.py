"""tests.py - test list shared by build.py, run_questa.py and run_verilator.py."""
T = 'TEST/Test_bus'           # paths relative to neumann_soc/ (simulators run there)
B = T + '/build'
PROGRAMS = ['bus']
KEYS = ('program loop', 'debug unit done', 'program done', 'MISMATCH', 'ERROR', 'checked', 'tb_bus', 'RESULT')
SOURCES = [T + '/tb/tb_bus.sv']


def plusargs(prog):
    return ['+NAME=' + prog, '+ROM=%s/rom.hex' % B, '+MAXCYC=3000000',
            '+IRAM=%s/%s_iram.hex' % (B, prog), '+DRAM=%s/%s_dram.hex' % (B, prog),
            '+GOLDEN=%s/golden/%s.golden' % (T, prog)]


def select(progs):
    p = progs or PROGRAMS
    bad = [x for x in p if x not in PROGRAMS]
    if bad:
        raise SystemExit('unknown %s; programs: %s' % (bad, ' '.join(PROGRAMS)))
    return p


def show(text):
    for line in text.splitlines():
        line = line.lstrip('# ')
        if any(k in line for k in KEYS) and not line.startswith('- '):
            print('   ' + line)
