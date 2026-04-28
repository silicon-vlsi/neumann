# Contribution Guideline

For this project we will use a simple **fork →  PR** workflow and a  `.gitignore` that covers **HDL/simulation artifacts** and **software build outputs**. 

Below is the full external contributor flow (commands + what each command/option means), assuming upstream is **`silicon-vlsi/neumann`** and default branch is **`main`**.


# Quick Reference

## Creating a *fork* (One time)

- Navigate to main repo: `https://github.com/silicon-vlsi/neumann`
- Click **Fork** → fork into your account: `https://github.com/<you>/neumann`
- Clone your *fork* to your local working directory (Linux shell)
  - HTTPS:
    - `git clone https://github.com/<you>/neumann.git`
    - `cd neumann`
  - **SSH**: (Highly Recommended)
    - `git clone git@github.com:<you>/neumann.git`
    - `cd neumann`

- Keep your *fork* and original repo (main) up to date. This can be done on the web interface using the `Sync Fork` button.
  - After `Sync Fork` on the web, update the local copy: `git pull`
- Make changes, inspect, and commit
  - Edit files, then inspect changes
    - `git status`
    - `git diff`
  - Stage changes (choose one)
    - `git add rtl/foo.v tb/foo_tb.sv`
  - Commit
    - `git commit -m "Add UART testbench for RX oversampling"`

- Open a **Pull Request** (PR) (fork → upstream)

- Go to your fork on GitHub and you should see something like "This branch is 2 commits ahead of `silicon-vlsi/neumann:main`
- Click `Contribute` → `Open Pull Request`
- Add a `title` and `description` to describe your contribution.
  - What changed + why
  - How to run (at least one) simulation, e.g.
    - `iverilog ...`
- Any wave capture / expected output (if applicable)
- *Check* All the chages shown in the tab below.
- Click `Create pull request` 
- If there are no conficts, it should show a badge `No conflicts with base branch`
- This will allow the maintainer to merge with the *upstream* repo.
---

# Detail Guide

## One-time local Git setup (contributor)

### Install & verify Git

```bash
git --version
```
Shows the installed Git version.

### Configure author identity

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

- `--global` stores these in your global Git config (~/.gitconfig), used for all repos.
- These values appear in commit metadata (author).

### (Optional but recommended) Configure line endings
On Linux/macOS (recommended):
```bash
git config --global core.autocrlf input
```
- Prevents accidental CRLF changes when editing text files across OSes.

---

## Fork workflow (external contributor)

### Fork on GitHub (**one time** on web)
- Go to: https://github.com/silicon-vlsi/neumann
- Click **Fork** → fork into your account: `https://github.com/<you>/neumann`

Reason: contributors push to their fork; original `/silicon-vlsi/neumann` repo stays protected; collaboration is via Pull-Requests (PRs).

---

## Collaborator clone locally and connect to upstream

### Clone *their fork*

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

## Make changes, inspect, and commit

### Edit files, then inspect changes
```bash
git status
git diff
```
- `git status`: what changed, what’s staged, what’s untracked.
- `git diff`: shows unstaged changes line-by-line.

Common useful variants:
- `git diff --stat` shows a summary of changed files/line counts.
- `git diff -- <path>` limits diff to one file.

### Stage changes (choose one)

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

### Commit
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

## Push 

- `git push`

Meaning:
- `git push` uploads commits to GitHub.


## Open a Pull Request (PR) (fork → upstream)

### Create PR on GitHub

- Go to your fork on GitHub and you should see something like "This branch is 2 commits ahead of `silicon-vlsi/neumann:main`
- Click `Contribute` → `Open Pull Request`
- Add a `title` and `description` to describe your contribution.
  - What changed + why
  - How to run (at least one) simulation, e.g.
    - `iverilog ...`
- Any wave capture / expected output (if applicable)
- *Check* All the chages shown in the tab below.
- Click `Create pull request` 
- If there are no conficts, it should show a badge `No conflicts with base branch`
- This will allow the maintainer to merge with the *upstream* repo.

---

