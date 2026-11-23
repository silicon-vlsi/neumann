"""tests.py - shared by build.py, run_spike.py, run_questa.py, run_verilator.py."""
import hashlib, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
T = os.path.relpath(HERE, ROOT).replace(os.sep, '/')          # TEST/Test_random
B = os.path.join(HERE, 'build')
GOLD = os.path.join(HERE, 'golden')
SEEDS = list(range(1, 101))            # rand_1 .. rand_100
BLOCKS, LENGTH = 40, 25


def names(args):
    """args: empty = all seeds; numbers or rand_<n> names."""
    if not args:
        return ['rand_%d' % s for s in SEEDS]
    return ['rand_%s' % a if not a.startswith('rand_') else a for a in args]


def plusargs(name, maxcyc=None):
    rel = T + '/build/'
    a = ['+ROM=' + rel + 'rom.hex', '+IRAM=' + rel + name + '_iram.hex', '+DRAM=' + rel + name + '_dram.hex',
         '+SIG=' + rel + name + '.signature', '+NAME=' + name]
    if maxcyc:
        a.append('+MAXCYC=%d' % maxcyc)
    return a


def image_md5(name, folder=B):
    h = hashlib.md5()
    for part in ('_iram.hex', '_dram.hex'):
        h.update(open(os.path.join(folder, name + part), 'rb').read())
    return h.hexdigest()


def check(name):
    """compare build/<name>.signature (RTL) with golden/<name>.sig (Spike)."""
    sig = os.path.join(B, name + '.signature')
    gold = os.path.join(GOLD, name + '.sig')
    if not os.path.exists(gold):
        return False, 'no Spike golden (run run_spike.py in the Docker container)'
    md5f = os.path.join(GOLD, name + '.md5')
    if os.path.exists(md5f) and open(md5f).read().strip() != image_md5(name):
        return False, 'golden was made from a different image: run run_spike.py again'
    if not os.path.exists(sig):
        return False, 'no signature (test did not finish)'
    got = [l.strip().lower() for l in open(sig) if l.strip()]
    exp = [l.strip().lower() for l in open(gold) if l.strip()]
    bad = [i for i in range(min(len(got), len(exp))) if got[i] != exp[i]]
    if len(got) != len(exp):
        return False, 'signature has %d words, Spike %d' % (len(got), len(exp))
    if bad:
        i = bad[0]
        where = 'data area word %d' % i if i < 256 else 'block %d, x%d' % ((i - 256) // 32, (i - 256) % 32 + 1)
        return False, '%d / %d words differ; first: %s: RTL %s, Spike %s' % (len(bad), len(exp), where, got[i], exp[i])
    return True, '%d words match Spike' % len(exp)
