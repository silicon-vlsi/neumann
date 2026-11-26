#!/usr/bin/env python3
"""run_coverage.py - run every soc_level suite with code coverage on, merge, and report.

usage:  python run_coverage.py                    Questa (default when vsim is on PATH)
        python run_coverage.py --sim verilator    Verilator (Linux / Docker)
        python run_coverage.py -s Test_arch Test_bus     some suites only
        python run_coverage.py --report-only      merge + report the existing coverage files

Coverage is collected on the RTL only (the files in neumann_soc.f), CLK_GATING=1.
Each suite is run through its own run_questa.py / run_verilator.py with NEUMANN_COV=1
(see covhook.py). Results in verification/soc_level/coverage/<sim>/:
  Questa:     <suite>__<test>.ucdb per run, merged.ucdb,
              summary.txt (totals), by_module.txt (per design unit), html/ (browse it)
  Verilator:  <suite>__<test>.dat per run, merged.dat, merged.info (lcov),
              summary.txt (line / toggle per RTL file), annotated/ (source with hit counts;
              lines starting with %000000 were never executed)
"""
import argparse, os, re, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import run_all
import covhook

RTL_DIRS = ('rtl/', 'rtl/peripherals/')


def run_suites(sim, suites):
    env = dict(os.environ, NEUMANN_COV='1')
    results = []
    for s in suites:
        env['NEUMANN_COV_SUITE'] = s
        cmd = run_all.command(s, sim, 1, True)
        logf = os.path.join(run_all.LOGS, '%s_%s_coverage.log' % (s, sim))
        os.makedirs(run_all.LOGS, exist_ok=True)
        print('== %s (coverage, %s)' % (s, sim))
        t0 = time.time()
        with open(logf, 'w') as log:
            r = subprocess.run(cmd, cwd=os.path.join(HERE, s), env=env, stdout=log, stderr=subprocess.STDOUT)
        last = [l for l in open(logf).read().splitlines() if l.startswith('PASSED')]
        print('   %s  (%.0f s)' % (last[-1] if last else 'no summary, see ' + logf, time.time() - t0))
        results.append((s, r.returncode == 0))
    return results


def report_questa(d):
    ucdbs = sorted(f for f in os.listdir(d) if f.endswith('.ucdb') and f != 'merged.ucdb')
    if not ucdbs:
        sys.exit('no .ucdb files in ' + d)
    merged = os.path.join(d, 'merged.ucdb')
    subprocess.run([covhook.tool('vcover'), 'merge', '-out', merged] + [os.path.join(d, f) for f in ucdbs], check=True,
                   stdout=subprocess.DEVNULL)
    with open(os.path.join(d, 'summary.txt'), 'w') as f:
        subprocess.run([covhook.tool('vcover'), 'report', '-summary', merged], stdout=f, stderr=subprocess.STDOUT)
    with open(os.path.join(d, 'by_module.txt'), 'w') as f:
        subprocess.run([covhook.tool('vcover'), 'report', '-bydu', merged], stdout=f, stderr=subprocess.STDOUT)
    with open(os.path.join(d, 'uncovered.txt'), 'w') as f:
        subprocess.run([covhook.tool('vcover'), 'report', '-details', '-zeros', '-bydu', merged], stdout=f, stderr=subprocess.STDOUT)
    subprocess.run([covhook.tool('vcover'), 'report', '-html', '-output', os.path.join(d, 'html'), merged],
                   stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    print('\nmerged %d runs -> %s' % (len(ucdbs), merged))
    print(open(os.path.join(d, 'summary.txt')).read()[-3000:])
    print('per module: %s\nnever hit:  %s\nHTML:       %s' % (os.path.join(d, 'by_module.txt'),
          os.path.join(d, 'uncovered.txt'), os.path.join(d, 'html', 'index.html')))


def report_verilator(d):
    dats = sorted(f for f in os.listdir(d) if f.endswith('.dat') and f != 'merged.dat')
    if not dats:
        sys.exit('no .dat files in ' + d)
    # every suite has its own testbench top (TOP.tb_arch.dut..., TOP.tb_boot.dut...): rename the
    # hierarchy to TOP.dut... so the same RTL point from different suites merges into one point
    norm = os.path.join(d, 'norm')
    if os.path.isdir(norm):
        shutil.rmtree(norm)
    os.makedirs(norm)
    pat = re.compile(r'\x01h\x02TOP\.tb_\w+\.dut')
    for f in dats:
        with open(os.path.join(d, f), encoding='latin-1') as src, \
             open(os.path.join(norm, f), 'w', encoding='latin-1') as dst:
            for line in src:
                dst.write(pat.sub('\x01h\x02TOP.dut', line))
    merged = os.path.join(d, 'merged.dat')
    subprocess.run([covhook.tool('verilator_coverage'), '--write', merged] + [os.path.join(norm, f) for f in dats], check=True,
                   stdout=subprocess.DEVNULL)
    info = os.path.join(d, 'merged.info')
    subprocess.run([covhook.tool('verilator_coverage'), '--write-info', info, merged], check=True, stdout=subprocess.DEVNULL)
    ann = os.path.join(d, 'annotated')
    if os.path.isdir(ann):
        shutil.rmtree(ann)
    subprocess.run([covhook.tool('verilator_coverage'), '--annotate', ann, '--annotate-min', '1', merged], cwd=ROOT,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # per-file line and toggle coverage, RTL only, from merged.dat
    per = {}
    for line in open(merged, encoding='latin-1'):
        m = re.match(r"C '(.*)' (\d+)", line.strip())
        if not m:
            continue
        fields = dict(kv.split('\x02', 1) for kv in m.group(1).split('\x01')[1:] if '\x02' in kv)
        fn = fields.get('f', '')
        if not fn.startswith(RTL_DIRS):
            continue
        k = 2 if 'toggle' in fields.get('page', '') else 0
        row = per.setdefault(fn, [0, 0, 0, 0])
        row[k] += 1
        row[k + 1] += int(m.group(2)) > 0
    pct = lambda h, n: 100.0 * h / n if n else 100.0
    tot = [sum(r[i] for r in per.values()) for i in range(4)]
    with open(os.path.join(d, 'summary.txt'), 'w') as f:
        f.write('Verilator coverage of the RTL, %d runs merged (CLK_GATING=1)\n' % len(dats))
        f.write('line = statement / branch points, toggle = every bit of every signal 0->1 and 1->0\n\n')
        f.write('%-46s %17s %19s\n' % ('file', 'line', 'toggle'))
        for fn, r in sorted(per.items(), key=lambda kv: pct(kv[1][1], kv[1][0])):
            f.write('%-46s %5d/%-5d %5.1f%% %6d/%-6d %5.1f%%\n' % (fn, r[1], r[0], pct(r[1], r[0]),
                                                               r[3], r[2], pct(r[3], r[2])))
        f.write('%-46s %5d/%-5d %5.1f%% %6d/%-6d %5.1f%%\n' % ('TOTAL (RTL)', tot[1], tot[0], pct(tot[1], tot[0]),
                                                           tot[3], tot[2], pct(tot[3], tot[2])))
    print('\nmerged %d runs -> %s' % (len(dats), merged))
    print(open(os.path.join(d, 'summary.txt')).read())
    print('annotated sources (%%000000 = never hit): %s' % ann)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sim', choices=['questa', 'verilator'],
                    default='questa' if covhook.have('vsim') else 'verilator')
    ap.add_argument('-s', '--suites', nargs='*', default=run_all.SUITES)
    ap.add_argument('--report-only', action='store_true')
    a = ap.parse_args()
    d = os.path.join(HERE, 'coverage', a.sim)
    if not a.report_only:
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)
        res = run_suites(a.sim, a.suites)
        bad = [s for s, ok in res if not ok]
        if bad:
            print('WARNING: failing suites (coverage still merged): ' + ' '.join(bad))
    (report_questa if a.sim == 'questa' else report_verilator)(d)


if __name__ == '__main__':
    main()
