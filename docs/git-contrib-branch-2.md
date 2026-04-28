# Contribution Guideline

For this projec we will use a lightweight “trunk-based + short-lived feature branches” workflow, with clear naming and a `.gitignore` that covers **HDL/simulation artifacts** and **software build outputs**. Below is a concrete, team-friendly setup that works well for mixed **Verilog + RISC‑V firmware/tests** repos like this.

# 1) Branching model 

## Permanent branches

- `main`: always **green**, protected, only merged via Pull-Request (PR).
- Optional: `release/<tag-or-version>` if you cut stable release lines.

## Short-lived branches (everything else)

- **Create** branches from `main`, 
- keep them **small**, 
- **merge** via PR, 
- **delete** after merge.

**Branch name convention**

Use a prefix + short scope + optional issue reference:

- `feat/<area>-<short-desc>` — new feature
- `fix/<area>-<short-desc>` — bug fix
- `refactor/<area>-<short-desc>` — no behavior change
- `docs/<short-desc>`
- `ci/<short-desc>`
- `chore/<short-desc>` — tooling, cleanup

**Areas** (examples for this repo type):

- `rtl`, `tb` (testbench), `sim`, `sw`, `drivers`, `tests`, `boot`, `scripts`, `doc`

**Examples**
- `feat/rtl-axi-lite-cleanup`
- `fix/sw-uart-regression`
- `feat/tests-riscv-compliance-rv32im`
- `ci/verilator-matrix`

## Tags
- Tag releases like `vX.Y.Z` (e.g., `v1.2.0`).
- If you ship FPGA bitstreams or prebuilt binaries, prefer **GitHub Releases artifacts**, not committed outputs.

# 2) Day-to-day commands (collaboration)

## Initial setup

```bash
git clone https://github.com/silicon-vlsi/neumann.git 
cd neumann
git remote add upstream https://github.com/silicon-vlsi/neumann.git # if you work from a fork
git fetch --all --prune
```

## Create a new feature branch

Always branch from updated `main`:

```bash
git checkout main
git pull --rebase upstream main   # or origin main if you push directly
git checkout -b feat/rtl-add-perf-counters
```

## Keep branch up to date (preferred: rebase)
```bash
git fetch upstream
git rebase upstream/main
```
If your team prefers merge commits instead:
```bash
git merge upstream/main
```

## Push and open PR
```bash
git push -u origin feat/rtl-add-perf-counters
```

## After PR merged
```bash
git checkout main
git pull --rebase upstream main
git branch -d feat/rtl-add-perf-counters
git push origin --delete feat/rtl-add-perf-counters
```

# 3) Commit conventions (helps review in HW/SW repos)

Mixed RTL/SW projects benefit from **scoped commits**:

- `rtl: ...`
- `tb: ...`
- `sw: ...`
- `tests: ...`
- `ci: ...`
- `docs: ...`

Example:
- `rtl: fix clock gating bug in core_region`
- `sw: add gpio smoke test`

Also consider requiring:
- **Signed-off-by** if you use DCO
- “No generated files” policy (except when explicitly required)

# 4) Pull-Requst (PR) practices (especially for RTL)

In PR description, include:
- What changed (RTL/SW)
- How it was verified:
  - simulator (Verilator/questa/iverilog) + command
  - test name(s)
  - FPGA build (if applicable)
- Any waveform/debug notes
- If RTL change affects SW ABI/register map, link the SW change too

# 5) `.gitignore` suggestions (Verilog + RISC‑V SW)

**NOTE** The `.gitignore` in the repo is already based on these suggestions.

You typically want to ignore:
- simulation outputs (VCD/FST, logs, compiled sim dirs)
- Verilator outputs
- synthesis/PNR outputs (Vivado/Quartus)
- SW build artifacts (ELF, OBJ, dep files)
- editor/OS junk


**Two important notes for HW repos:**
1. If your flow *expects* checked-in `.hex/.mem` (e.g., golden ROM images), don't ignore them globally—ignore only the build-generated locations (like `build/**`).
2. If you have a `sim/` directory that contains sources you *do* want tracked, don’t ignore `sim/` wholesale—ignore `sim/**/work`, `sim/**/obj_dir`, etc. (path-specific ignores are safer).

# 6) Repo structure conventions that help
If you have influence on layout, a clean split makes ignores and CI easier:
- `rtl/` (synthesizable Verilog/SystemVerilog)
- `tb/` (testbenches)
- `sw/` (firmware/tests)
- `scripts/` (build + run helpers)
- `fpga/` (board projects)
- `ci/` or `.github/`

