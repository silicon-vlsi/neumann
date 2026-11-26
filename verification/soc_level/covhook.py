"""covhook.py - code-coverage hook shared by every suite's run_questa.py / run_verilator.py.

When the environment variable NEUMANN_COV is set (run_coverage.py does that), the runners
call covhook.run() instead of subprocess.run() and the simulator commands are changed:

  Questa     vlog: the RTL (-f neumann_soc.f) is compiled with +cover=bcesft
                   (branch, condition, expression, statement, FSM, toggle); the testbench
                   files are compiled in a second vlog call without coverage.
             vsim: -coverage, and "coverage save -onexit <ucdb>" before "run -all".
  Verilator  verilator: --coverage-line --coverage-toggle, and our own main()
                        (coverage/cov_main_<top>.cpp, the --main loop plus a coverage write:
                        Verilator 5.0's generated main does not write coverage)
             ./sim:     NEUMANN_COV_FILE=<dat> in the environment

Coverage files go to verification/soc_level/coverage/<questa|verilator>/<suite>__<test>.ucdb / .dat.
Without NEUMANN_COV, covhook.run() is exactly subprocess.run().
"""
import os, re, subprocess

TEST_DIR = os.path.dirname(os.path.abspath(__file__))
_count = {'n': 0}


# ---------------------------------------------------------------------------
# Tool finder: makes every runner work on Windows, Linux and Docker without
# editing PATH by hand. Order: 1) environment variable, 2) PATH, 3) common
# install folders. A folder found this way is added to PATH for child tools
# (vsim -> vopt, verilator -> make / g++).
#   Override:  NEUMANN_QUESTA_BIN=<folder with vsim>   NEUMANN_VERILATOR_BIN=<folder with verilator>
#   Also read: QUESTA_HOME, MODEL_TECH, VERILATOR_ROOT
# ---------------------------------------------------------------------------
import glob, shutil, sys

QUESTA_TOOLS = ('vlib', 'vlog', 'vsim', 'vopt', 'vcover', 'vmap')
VERILATOR_TOOLS = ('verilator', 'verilator_coverage')
_found = {}


def _home(*p):
    return os.path.join(os.path.expanduser('~'), *p)


def _questa_dirs():
    d = []
    for v in ('NEUMANN_QUESTA_BIN',):
        if os.environ.get(v):
            d.append(os.environ[v])
    for v in ('QUESTA_HOME', 'MODEL_TECH', 'MTI_HOME'):
        e = os.environ.get(v)
        if e:
            d += [e, os.path.join(e, 'bin'), os.path.join(e, 'win64'), os.path.join(e, 'linux_x86_64')]
    if os.name == 'nt':
        pats = [r'C:\intelFPGA*\*\questa_fse\win64', r'C:\intelFPGA_pro\*\questa_fe\win64',
                r'C:\intelFPGA*\*\modelsim_ase\win32aloem', r'C:\altera*\*\questa_fse\win64',
                r'C:\questasim*\win64', r'C:\questa_sim*\win64', r'C:\Program Files\questasim*\win64',
                r'C:\Program Files\Mentor*\*\win64', r'C:\Siemens\*\questasim*\win64',
                r'D:\intelFPGA*\*\questa_fse\win64', r'D:\questasim*\win64']
    else:
        pats = ['/opt/questasim*/bin', '/opt/questa*/questasim/bin', '/opt/mentor/*/questasim/bin',
                '/opt/siemens/*/questasim/bin', '/tools/*/questasim/bin', '/eda/*/questasim/bin',
                _home('intelFPGA*', '*', 'questa_fse', 'bin'), '/opt/intelFPGA*/*/questa_fse/bin',
                _home('eda', '*', 'bin'), '/usr/local/bin']
    for p in pats:
        d += sorted(glob.glob(p), reverse=True)           # newest version first
    return d


def _verilator_dirs():
    d = []
    if os.environ.get('NEUMANN_VERILATOR_BIN'):
        d.append(os.environ['NEUMANN_VERILATOR_BIN'])
    if os.environ.get('VERILATOR_ROOT'):
        d += [os.path.join(os.environ['VERILATOR_ROOT'], 'bin'), os.environ['VERILATOR_ROOT']]
    if os.name == 'nt':
        pats = [r'C:\msys64\mingw64\bin', r'C:\msys64\ucrt64\bin', r'C:\msys64\clang64\bin',
                r'C:\verilator*\bin', r'C:\Program Files\verilator*\bin', r'C:\oss-cad-suite\bin']
    else:
        pats = ['/foss/tools/bin', '/foss/tools/verilator/bin', '/opt/verilator*/bin',
                '/usr/local/bin', '/usr/bin', _home('oss-cad-suite', 'bin'), '/opt/oss-cad-suite/bin',
                _home('eda', 'verilator*', 'bin'), _home('.local', 'bin')]
    for p in pats:
        d += sorted(glob.glob(p), reverse=True)
    return d


def _exe_in(folder, name):
    for n in ([name + '.exe', name + '.bat', name] if os.name == 'nt' else [name]):
        f = os.path.join(folder, n)
        if os.path.isfile(f) and os.access(f, os.X_OK):
            return f
    return None


def _hint(name):
    if name in VERILATOR_TOOLS:
        return ('Verilator not found. Install it (Linux: apt install verilator, or the oss-cad-suite;\n'
                'Windows: MSYS2 "pacman -S mingw-w64-x86_64-verilator", or use Docker / WSL),\n'
                'or set NEUMANN_VERILATOR_BIN=<folder that holds verilator>. On Windows the Questa\n'
                'runners (run_questa.py) are the easy path.')
    return ('Questa not found. Add its bin folder (the one with vsim / vlog) to PATH, or set\n'
            'NEUMANN_QUESTA_BIN=<that folder> (Windows example: C:\\intelFPGA\\23.1std\\questa_fse\\win64).')


def tool(name, required=True):
    """full path of a simulator tool (vlib/vlog/vsim/vcover/verilator/...); exits with a
    clear message if it cannot be found and required=True; None if not required."""
    if name in _found:
        return _found[name]
    path = shutil.which(name)
    if not path:
        dirs = _questa_dirs() if name in QUESTA_TOOLS else _verilator_dirs() if name in VERILATOR_TOOLS else []
        for d in dirs:
            path = _exe_in(d, name)
            if path:
                break
    if path:
        folder = os.path.dirname(path)
        if folder not in os.environ.get('PATH', '').split(os.pathsep):
            os.environ['PATH'] = folder + os.pathsep + os.environ.get('PATH', '')
            print('== using %s from %s' % (name, folder))
        _found[name] = path
        return path
    if required:
        sys.exit('\nERROR: cannot find "%s".\n%s\n' % (name, _hint(name)))
    return None


def have(name):
    return tool(name, required=False) is not None



# RISC-V compiler and Spike: their folders are added to PATH so build.py's
# shutil.which() and run_spike.py find them without manual PATH setup.
#   Override: NEUMANN_RISCV_BIN=<folder with riscv*-gcc or clang>   NEUMANN_SPIKE_BIN=<folder with spike>
#   Also read: RISCV, RISCV_PATH, RISCV_TOOLCHAIN (folder or its bin/)
RISCV_GCC = ('riscv64-unknown-elf-gcc', 'riscv32-unknown-elf-gcc', 'riscv-none-elf-gcc',
             'riscv64-elf-gcc', 'riscv32-elf-gcc')


def _riscv_dirs():
    d = []
    for v in ('NEUMANN_RISCV_BIN', 'RISCV', 'RISCV_PATH', 'RISCV_TOOLCHAIN'):
        e = os.environ.get(v)
        if e:
            d += [e, os.path.join(e, 'bin')]
    if os.name == 'nt':
        a = os.environ.get('APPDATA', '')
        pats = [os.path.join(a, 'xPacks', '@xpack-dev-tools', 'riscv-none-elf-gcc', '*', '.content', 'bin'),
                r'C:\xpack*\riscv-none-elf-gcc*\bin', r'C:\xpack-riscv-none-elf-gcc*\bin',
                r'C:\riscv*\bin', r'C:\SysGCC\risc-v\bin', r'C:\Program Files\LLVM\bin',
                r'C:\msys64\mingw64\bin', r'C:\msys64\ucrt64\bin', r'C:\msys64\clang64\bin']
    else:
        pats = ['/opt/riscv*/bin', '/opt/riscv/*/bin', _home('riscv*', 'bin'), '/foss/tools/bin',
                '/foss/tools/riscv-gnu-toolchain*/bin', '/foss/tools/riscv*/bin', '/usr/local/riscv*/bin',
                _home('.local', 'xPacks', '@xpack-dev-tools', 'riscv-none-elf-gcc', '*', '.content', 'bin'),
                _home('eda', 'riscv*', 'bin'), '/usr/local/bin', '/usr/bin']
    for p in pats:
        d += sorted(glob.glob(p), reverse=True)
    return d


def _prepend(folder):
    if folder and folder not in os.environ.get('PATH', '').split(os.pathsep):
        os.environ['PATH'] = folder + os.pathsep + os.environ.get('PATH', '')


def add_riscv_paths():
    """put the first folder holding a RISC-V GCC (or clang + ld.lld) on PATH. Safe to call
    many times; does nothing if one is already on PATH."""
    if any(shutil.which(g) for g in RISCV_GCC) or (shutil.which('clang') and shutil.which('ld.lld')):
        return
    for d in _riscv_dirs():
        if any(_exe_in(d, g) for g in RISCV_GCC) or (_exe_in(d, 'clang') and _exe_in(d, 'ld.lld')):
            _prepend(d)
            print('== using RISC-V toolchain from %s' % d)
            return


def find_spike(name='spike'):
    """full path of spike, or None."""
    if os.path.exists(name):
        return name
    p = shutil.which(name)
    if p:
        return p
    dirs = [os.environ.get('NEUMANN_SPIKE_BIN', '')] + _riscv_dirs() + \
           (['/opt/spike/bin', '/foss/tools/spike/bin', _home('spike', 'bin')] if os.name != 'nt' else [])
    for d in dirs:
        if d:
            f = _exe_in(d, name)
            if f:
                _prepend(os.path.dirname(f))
                return f
    return None



def dpi_c(obj, src):
    """copy the DPI C helper into Verilator's --Mdir and return that path. Some Verilator
    versions (seen with 5.050 on a mounted folder) write a wrong path for user C files into
    the generated makefile; a file inside the Mdir itself is always found. Only the bare file
    name is returned: make runs inside the Mdir (make -C), so the name always resolves there,
    however deep the suite folder is."""
    import shutil as _sh
    os.makedirs(obj, exist_ok=True)
    dst = os.path.join(obj, os.path.basename(src))
    _sh.copyfile(src, dst)
    return os.path.basename(dst)


def _resolve(cmd):
    cmd = list(cmd)
    if cmd and os.path.basename(str(cmd[0])) in QUESTA_TOOLS + VERILATOR_TOOLS:
        cmd[0] = tool(os.path.basename(str(cmd[0])))
    return cmd


def enabled():
    return bool(os.environ.get('NEUMANN_COV'))


def cov_dir(sim):
    d = os.path.join(TEST_DIR, 'coverage', sim)
    os.makedirs(d, exist_ok=True)
    return d


def _suite():
    return os.environ.get('NEUMANN_COV_SUITE', 'suite')


def _test_name(args, prefix=''):
    name = None
    for a in args:
        for key in ('+NAME=', '+EXPECT='):
            if isinstance(a, str) and a.startswith(key):
                name = a[len(key):]
    for a in args:
        if isinstance(a, str) and a.startswith('+BOOT='):
            name = (name or 'run') + '_' + a[len('+BOOT='):]
    if name is None:
        _count['n'] += 1
        name = 'run%d' % _count['n']
    return re.sub(r'[^A-Za-z0-9_.-]', '_', prefix + name)


def _vlog(cmd, kw):
    """split one vlog call into RTL-with-coverage + testbench-without-coverage."""
    if '-f' not in cmd:
        return [cmd]
    i = cmd.index('-f')
    head = [c for c in cmd[:i]]                      # vlog -work ... -sv -timescale ... (+incdir)
    base = [c for c in head if not c.startswith('+incdir')]
    rtl = head + ['+cover=bcesft'] + cmd[i:i + 2]
    tb = cmd[i + 2:]
    return [rtl] + ([base + tb] if tb else [])


def _vsim(cmd):
    cmd = list(cmd)
    if '-c' not in cmd:                              # GUI runs: leave alone
        return cmd
    cg = ''
    for a in cmd:
        if a.startswith('-GCLK_GATING='):
            cg = 'cg' + a.split('=')[1] + '_'
    ucdb = os.path.join(cov_dir('questa'), '%s__%s.ucdb' % (_suite(), _test_name(cmd, cg))).replace('\\', '/')
    cmd.insert(1, '-coverage')
    j = cmd.index('-do')
    cmd[j + 1] = 'coverage save -onexit {%s}; %s' % (ucdb, cmd[j + 1])
    return cmd


MAIN = r'''// cov_main - Verilator --main loop + coverage write (generated by verification/soc_level/covhook.py)
#include "verilated.h"
#include "verilated_cov.h"
#include "V%(top)s.h"
#include <cstdlib>
int main(int argc, char** argv, char**) {
    Verilated::debug(0);
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->commandArgs(argc, argv);
    const std::unique_ptr<V%(top)s> topp{new V%(top)s{contextp.get()}};
    while (!contextp->gotFinish()) {
        topp->eval();
        if (!topp->eventsPending()) break;
        contextp->time(topp->nextTimeSlot());
    }
    topp->final();
    const char* f = std::getenv("NEUMANN_COV_FILE");
    contextp->coveragep()->write(f ? f : "coverage.dat");
    return 0;
}
'''


def _cov_main(top):
    p = os.path.join(TEST_DIR, 'coverage', 'cov_main_%s.cpp' % top)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w') as f:
        f.write(MAIN % {'top': top})
    return p


def run(cmd, **kw):
    exe = os.path.basename(str(cmd[0]))
    if exe.lower().endswith('.exe'):
        exe = exe[:-4]
    cmd = _resolve(cmd)
    if not enabled():
        return subprocess.run(cmd, **kw)
    if exe == 'vlog':
        r = None
        for c in _vlog(list(cmd), kw):
            r = subprocess.run(c, **kw)
            if r.returncode != 0:
                return r
        return r
    if exe == 'vsim':
        return subprocess.run(_vsim(cmd), **kw)
    if exe == 'verilator':
        cmd = list(cmd)
        top = cmd[cmd.index('--top-module') + 1]
        cmd.remove('--binary')                                  # = --main --exe --build --timing
        cmd[1:1] = ['--cc', '--exe', '--build', '--coverage-line', '--coverage-toggle', _cov_main(top)]
        if '--timing' not in cmd:
            cmd.insert(1, '--timing')
        return subprocess.run(cmd, **kw)
    if exe == 'sim':                                 # a Verilator-built simulator
        cg = ''
        m = re.search(r'obj_(cg\d)', str(cmd[0]))
        if m:
            cg = m.group(1) + '_'
        m = re.search(r'obj_cg\d_(\w+)', str(cmd[0]))
        if m:
            cg += m.group(1) + '_'
        dat = os.path.join(cov_dir('verilator'), '%s__%s.dat' % (_suite(), _test_name(cmd, cg)))
        env = dict(kw.pop('env', None) or os.environ, NEUMANN_COV_FILE=dat)
        return subprocess.run(cmd, env=env, **kw)
    return subprocess.run(cmd, **kw)
