#!/usr/bin/env python3
"""run_all.py - run every test suite in verification/soc_level/, one after the other, and print a summary.

usage:  python run_all.py                        Questa, CLK_GATING=1, all suites
        python run_all.py --cg 0                 Questa, CLK_GATING=0 (suites that support it)
        python run_all.py --cg both              Questa, CLK_GATING=1 then 0
        python run_all.py --sim verilator        Verilator (Linux / Docker), CLK_GATING 1 and 0
        python run_all.py --sim verilator --quick   Verilator, CLK_GATING=1 only
        python run_all.py -s Test_arch Test_bus  only these suites
        python run_all.py --stop                 stop at the first failing suite

Suites, in this order: Test_via_sdc, Test_boot_programs, Test_arch, Test_periph_irq,
Test_bus, Test_random. Each suite's own run_questa.py / run_verilator.py does the work;
its full output goes to verification/soc_level/run_all_logs/<suite>_<sim>[_cg<g>].log.
Test_random compares with Spike goldens that are already in Test_random/golden/
(made once with run_spike.py in Docker); Spike itself is not needed here.
Exit code 0 only if every suite passed.
"""
import argparse, os, re, shutil, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import covhook

HERE = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(HERE, 'run_all_logs')
SUITES = ['Test_via_sdc', 'Test_boot_programs', 'Test_arch', 'Test_periph_irq', 'Test_bus', 'Test_random']
QUESTA_CG0 = {'Test_arch', 'Test_periph_irq', 'Test_bus', 'Test_random'}   # run_questa.py --cg 0 exists
VERILATOR_JOBS = {'Test_boot_programs': 4, 'Test_arch': 8}                  # -j where supported


def command(suite, sim, cg, quick):
    """argument list for one suite, or None if this combination is not available."""
    py = sys.executable
    if sim == 'questa':
        if cg == 0 and suite not in QUESTA_CG0:
            return None
        return [py, 'run_questa.py'] + (['--cg', '0'] if cg == 0 else [])
    cmd = [py, 'run_verilator.py']
    if quick:
        cmd.append('--quick')
    if suite in VERILATOR_JOBS:
        cmd += ['-j', str(VERILATOR_JOBS[suite])]
    return cmd


def main():
    ap = argparse.ArgumentParser(description='run every soc_level suite one by one')
    ap.add_argument('--sim', choices=['questa', 'verilator'],
                    default='questa' if covhook.have('vsim') else 'verilator')
    ap.add_argument('--cg', choices=['1', '0', 'both'], default='1',
                    help='Questa: CLK_GATING value(s). Verilator runs 1 and 0 unless --quick')
    ap.add_argument('--quick', action='store_true', help='Verilator: CLK_GATING=1 only')
    ap.add_argument('-s', '--suites', nargs='*', default=SUITES)
    ap.add_argument('--stop', action='store_true', help='stop at the first failing suite')
    a = ap.parse_args()
    bad = [s for s in a.suites if s not in SUITES]
    if bad:
        sys.exit('unknown suite %s; choose from %s' % (bad, ' '.join(SUITES)))
    os.makedirs(LOGS, exist_ok=True)

    if a.sim == 'questa':
        runs = [(s, cg) for cg in ([1, 0] if a.cg == 'both' else [int(a.cg)]) for s in a.suites]
    else:
        runs = [(s, None) for s in a.suites]

    print('run_all: %s, %d run(s); logs in %s' % (a.sim, len(runs), LOGS))
    summary = []
    t_all = time.time()
    for suite, cg in runs:
        tag = suite + ('' if cg is None else ' (CLK_GATING=%d)' % cg)
        cmd = command(suite, a.sim, cg if cg is not None else 1, a.quick)
        if cmd is None:
            print('\n== %s: skipped (run_questa.py has no --cg 0 for this suite)' % tag)
            summary.append((tag, 'SKIP', 'no CLK_GATING=0 option', 0))
            continue
        logf = os.path.join(LOGS, '%s_%s%s.log' % (suite, a.sim, '' if cg is None else '_cg%d' % cg))
        print('\n== %s: %s' % (tag, ' '.join(os.path.basename(c) if i == 0 else c for i, c in enumerate(cmd))))
        t0 = time.time()
        with open(logf, 'w') as log:
            p = subprocess.Popen(cmd, cwd=os.path.join(HERE, suite), stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, bufsize=1)
            lines = []
            for line in p.stdout:
                log.write(line)
                lines.append(line.rstrip())
                if re.search(r'\b(PASS|FAIL|SKIP)\b|PASSED|ERROR|Error', line):
                    print('   ' + line.rstrip().lstrip('# '))
            rc = p.wait()
        dt = time.time() - t0
        passed = [l for l in lines if l.startswith('PASSED')]
        last = passed[-1] if passed else ''
        m = re.match(r'PASSED (\d+) / (\d+)', last)
        ok = rc == 0 and bool(m) and m.group(1) == m.group(2) and 'FAILED' not in last
        status = 'PASS' if ok else 'FAIL'
        detail = last.replace('PASSED ', '') if last else 'no summary line (see log)'
        if len(passed) > 1:                     # Verilator: one line for the whole run
            detail = passed[-1].replace('PASSED ', '')
        summary.append((tag, status, detail, dt))
        if not ok and a.stop:
            print('\n--stop: stopping after the first failing suite')
            break

    print('\n' + '=' * 78)
    print('run_all summary (%s, %.0f s)' % (a.sim, time.time() - t_all))
    print('=' * 78)
    for tag, status, detail, dt in summary:
        print('  %-36s %-4s  %s%s' % (tag, status, detail, ('  [%.0f s]' % dt) if dt else ''))
    n_fail = sum(1 for s in summary if s[1] == 'FAIL')
    n_pass = sum(1 for s in summary if s[1] == 'PASS')
    print('=' * 78)
    print('%d suite run(s) passed, %d failed, %d skipped' % (n_pass, n_fail, len(summary) - n_pass - n_fail))
    sys.exit(1 if n_fail else 0)


if __name__ == '__main__':
    main()
