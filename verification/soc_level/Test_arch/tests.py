"""tests.py - shared by build.py / run_*.py: test list, memory maps, plusargs, signature check."""
import glob, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
T = os.path.relpath(HERE, ROOT).replace(os.sep, '/')          # verification/soc_level/Test_arch
B = os.path.join(HERE, 'build')
SUITE = os.path.join(HERE, 'riscv-arch-test')

# suite -> -march. privilege tests are not run: they need mtval / misaligned traps,
# which this core does not have (see README).
SUITES = {'I': 'rv32i', 'C': 'rv32ic', 'Zifencei': 'rv32i_zifencei'}

# memory maps.  std = the chip (IRAM 16 KB at 0x8000_0000, DRAM 8 KB at 0x8001_0000).
# big = test-only 2 MB IRAM window, DRAM at 0x8020_0000 (config_big/config.vh), for the
# far-branch / jal tests whose code does not fit 16 KB.
MAPS = {
    'std': dict(iram_len=16 * 1024, dram_base=0x80010000, dram_len=8 * 1024,
                iram_phys=0x3FFF, incdir=None),
    'big': dict(iram_len=2 * 1024 * 1024, dram_base=0x80200000, dram_len=8 * 1024,
                iram_phys=0x1FFFFF, incdir=T + '/config_big'),
}


# tests that are built but not run, with the reason (shown as SKIP)
SKIP = {
    'C-cebreak-01': 'needs a trap handler with mscratch/mtval; on this core EBREAK enters debug mode',
}


def all_tests():
    """[(suite, name)] in a stable order, e.g. ('I', 'add-01')."""
    out = []
    for s in SUITES:
        for f in sorted(glob.glob(os.path.join(SUITE, 'rv32i_m', s, 'src', '*.S'))):
            out.append((s, os.path.basename(f)[:-2]))
    return out


def tid(suite, name):
    return '%s-%s' % (suite, name)


def select(names):
    """names: empty = all; 'I' / 'C' / 'Zifencei' = a suite; 'add-01' or 'I-add-01' = one test."""
    tl = all_tests()
    if not names:
        return tl
    out = []
    for n in names:
        hit = [t for t in tl if n in (t[0], t[1], tid(*t))]
        if not hit:
            raise SystemExit('unknown test %s' % n)
        out += [t for t in hit if t not in out]
    return out


def read_maps():
    """build/manifest.txt: '<test id> <std|big>' per line, written by build.py."""
    m = {}
    with open(os.path.join(B, 'manifest.txt')) as f:
        for l in f:
            if l.strip():
                k, v = l.split()
                m[k] = v
    return m


def plusargs(suite, name, maxcyc=None):
    t = tid(suite, name)
    rel = T + '/build/'
    a = ['+ROM=' + rel + 'rom.hex', '+IRAM=' + rel + t + '_iram.hex',
         '+DRAM=' + rel + t + '_dram.hex', '+SIG=' + rel + t + '.signature', '+NAME=' + t]
    if maxcyc:
        a.append('+MAXCYC=%d' % maxcyc)
    return a


def reference(suite, name):
    return os.path.join(SUITE, 'rv32i_m', suite, 'references', name + '.reference_output')


def check(suite, name):
    """compare build/<id>.signature with the reference. returns (ok, message)."""
    t = tid(suite, name)
    sig = os.path.join(B, t + '.signature')
    if not os.path.exists(sig):
        return False, 'no signature (test did not finish)'
    got = [l.strip().lower() for l in open(sig) if l.strip()]
    exp = [l.strip().lower() for l in open(reference(suite, name)) if l.strip()]
    bad = [i for i in range(min(len(got), len(exp))) if got[i] != exp[i]]
    if len(got) != len(exp):
        return False, 'signature has %d words, reference %d%s' % (
            len(got), len(exp), ('; first mismatch at word %d' % bad[0]) if bad else '')
    if bad:
        i = bad[0]
        return False, '%d / %d words differ; first: word %d got %s expected %s' % (
            len(bad), len(exp), i, got[i], exp[i])
    return True, '%d words match' % len(exp)
