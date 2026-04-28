# Contribution Guideline

For this project we will use a lightweight **fork → feature branch → PR** workflow with clear naming and a `.gitignore` that covers **HDL/simulation artifacts** and **software build outputs**. Below is a concrete, team-friendly setup that works well for mixed **Verilog + RISC‑V firmware/tests** repos like this.
Use the **fork → feature branch → PR** workflow. For Verilog projects, add one more convention: contributors should include a **minimal simulator command** (iverilog/verilator/etc.) in the PR description so you can reproduce quickly.

Below is the full external contributor flow (commands + what each command/option means), assuming upstream is **`silicon-vlsi/neumann`** and default branch is **`main`**.


# Quick Reference

## Creating a *fork* and a working *branch* 

- Navigate to main repo: `https://github.com/silicon-vlsi/neumann`
- Click **Fork** → fork into your account: `https://github.com/<you>/neumann`
- Clone your *fork* to your local working directory (Linux shell)
  - HTTPS:
    - `git clone https://github.com/<you>/neumann.git`
    - `cd neumann`
  - SSH (Highly Recommended):
    - `git clone git@github.com:<you>/neumann.git`
    - `cd neumann`
- Add the main repo (`/silicon-vlsi/neumann`) as the *upstream*:
  - `git remote add upstream https://github.com/silicon-vlsi/neumann.git`
  - `git remote -v` to check if upstream is added as a remote URL

- Keep your *fork* (main)  and original repo (main) up to date
  - `git checkout main` (This is the local *main* of your form)
  - `git fetch upstream` (This is *main* of the original repo)
  - `git merge upstream/main` (Merge orginal repo with yout fork)
- After your local `main` matches upstream (orginal repo),  update your fork on GitHub (origin/main)
  - `git push origin main`
- **NOTE** Your *fork* can be synced with the original repo on the web and synced in the local driectory by running `git pull`
- Create and switch to a new *branch*:
  - `git checkout -b feature/add-uart-tb`
  - You can type `git branch` to see which branch you are on.
  - Branch naming tips: `feature/...`, `fix/...`, `docs/...`, `tb/...` (testbench), `ci/...` are common.

- Make changes, inspect, and commit
  - Edit files, then inspect changes
    - `git status`
    - `git diff`
  - Stage changes (choose one)
    - `git add rtl/foo.v tb/foo_tb.sv`
  - Commit
    - `git commit -m "Add UART testbench for RX oversampling"`

---

# Detail Guide

## A. One-time local Git setup (contributor)

### 1) Install & verify Git

```bash
git --version
```
Shows the installed Git version.

### 2) Configure author identity

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

- `--global` stores these in your global Git config (~/.gitconfig), used for all repos.
- These values appear in commit metadata (author).

### 3) (Optional but recommended) Configure line endings
On Linux/macOS (recommended):
```bash
git config --global core.autocrlf input
```
- Prevents accidental CRLF changes when editing text files across OSes.

---

## B. Fork workflow (external contributor)

### 1) Fork on GitHub (web)
- Go to: https://github.com/silicon-vlsi/neumann
- Click **Fork** → fork into your account: `https://github.com/<you>/neumann`

Reason: contributors push to their fork; original `/silicon-vlsi/neumann` repo stays protected; collaboration is via Pull-Requests (PRs).

---

## C. Collaborator clone locally and connect to upstream

### 2) Clone *their fork*

HTTPS:

```bash
git clone https://github.com/<you>/neumann.git
cd neumann
```

SSH:
```bash
git clone git@github.com:<you>/neumann.git
cd neumann
```

**SSH** method is recommended for frequent contribution. 

What `git clone` does:
- Downloads the repo history and working files.
- Creates a remote named `origin` pointing to the _fork URL_ (`/<you>/neumann`) you cloned.

Common options:
- `--depth 1` (shallow clone, faster; less history):
  ```bash
  git clone --depth 1 https://github.com/<you>/neumann.git
  ```
- `-b main` (explicitly checkout a branch after clone; not required here since default is main):
  ```bash
  git clone -b main https://github.com/<you>/neumann.git
  ```

### 3) Add the upstream remote (your repo)

**NOTE** This is required **one time**

```bash
git remote -v
git remote add upstream https://github.com/silicon-vlsi/neumann.git
git remote -v
```

Meaning:
- `git remote -v` lists remotes and their fetch/push URLs.
- `git remote add upstream <url>` adds a second remote.
- You now typically:
  - **fetch from** `upstream`  (original repo)
  - **push to** `origin`       (your forked repo)

---

## D. Keep your *fork* (main)  and original repo (main) up to date

### 4) Update local `main` from upstream

```bash
git checkout main
git fetch upstream
git merge upstream/main
```

What each does:
- `git checkout main`: switches your working directory to the `main` branch.
- `git fetch upstream`: downloads upstream branches/commits but does not modify your working tree.
- `git merge upstream/main`: merges upstream’s `main` into your local `main`.

Notes/options:
- If you have local changes, `merge` may conflict; resolve conflicts then commit.
- Alternative “fetch+merge in one step” is `git pull`, but fetch+merge is clearer for beginners:
  ```bash
  git pull upstream main
  ```
  (`git pull <remote> <branch>` = fetch + merge)

### 5) Update your fork on GitHub (origin/main)

After your local `main` matches upstream:
```bash
git push origin main
```
This keeps your fork’s `main` current too.

**NOTE** You can keep the *main* and *branches* synced from GitHub web interface too and do a `git pull` in your local working directory to keep evertything synced up.

---

## E. Create a feature branch (required for Pull Requests (PRs))

### 6) Create and switch to a new branch

```bash
git checkout -b feature/add-uart-tb
```

You can type `git branch` to see which branch you are on.

Meaning:
- `-b` creates the branch and checks it out in one command.
- Never commit directly on `main`; always use a branch per change.

Branch naming tips:
- `feature/...`, `fix/...`, `docs/...`, `tb/...` (testbench), `ci/...` are common.

---

## F. Make changes, inspect, and commit

### 7) Edit files, then inspect changes
```bash
git status
git diff
```
- `git status`: what changed, what’s staged, what’s untracked.
- `git diff`: shows unstaged changes line-by-line.

Common useful variants:
- `git diff --stat` shows a summary of changed files/line counts.
- `git diff -- <path>` limits diff to one file.

### 8) Stage changes (choose one)

Stage specific files (recommended):
```bash
git add rtl/foo.v tb/foo_tb.sv
```

Stage everything (use carefully):
```bash
git add -A
```

What `git add` does:
- Adds selected content to the **staging area** (what the next commit will contain).

Important options:
- `git add -p` (patch mode): interactively stage parts of files (great for clean commits).
- `git add -A` stages new/modified/deleted files.

### 9) Commit
```bash
git commit -m "Add UART testbench for RX oversampling"
```

Meaning:
- Creates a new commit from the staged snapshot.

Common commit options:
- `--amend`: replace the last commit (useful before pushing):
  ```bash
  git commit --amend
  ```
  Don’t amend commits others may already be basing work on; if you already pushed, amending rewrites history.

---


## G. Push the branch to their fork

### 10) First push (sets upstream tracking)
```bash
git push --set-upstream origin feature/add-uart-tb
```

Meaning:
- `git push` uploads commits to GitHub.
- `--set-upstream origin <branch>` links local branch to `origin/<branch>`.
- After this, plain `git push` / `git pull` works without specifying remote+branch.

Next pushes:
```bash
git push
```

---

## H. Open a Pull Request (fork → upstream)

### 11) Create PR on GitHub
Go to your fork on GitHub and click **Compare & pull request**, or:
- Base repo: `silicon-vlsi/neumann`
- Base branch: `main`
- Head repo: `<you>/neumann`
- Compare branch: `feature/add-uart-tb`

In the PR description, include:
- What changed + why
- How to run (at least one) simulation, e.g.
  - `iverilog ...`
  - `verilator --lint-only ...`
- Any wave capture / expected output (if applicable)

---

## I. Keep the PR branch updated if upstream changed

### 12) Sync changes from upstream into your branch
```bash
git fetch upstream
git checkout feature/add-uart-tb
git merge upstream/main
git push
```

Meaning:
- Brings your PR branch up-to-date with latest upstream `main`.
- If merge conflicts occur:
  - edit conflict markers
  - `git add <resolved files>`
  - `git commit`
  - `git push`

(Alternative approach is “rebase”, but merge is easier/safer for beginners.)

---
