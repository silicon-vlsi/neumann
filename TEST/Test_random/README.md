# Test_random — random instructions checked against Spike

`gen_random.py` makes random RV32IC programs; each runs on the RTL and on Spike (the
RISC-V reference ISA simulator) and the two **signatures** are compared word by word.

## Programs

100 programs (`rand_1` … `rand_100`, seed = number), each 40 blocks × 25 random instructions:
- RV32I ALU (register, immediate, shifts with edge values 0 / 1 / 31), `lui`, `auipc`
- loads / stores of all sizes (aligned) within ±512 bytes of a 1 KB random data area
- forward branches (all six, taken or not depending on the random data, equal operands
  sometimes), `jal`, `jalr` (via `la`), `c.beqz` / `c.bnez`, `c.j` / `c.jal`
- explicit RVC: `c.addi c.li c.lui c.mv c.add c.sub c.xor c.or c.and c.andi c.slli c.srli c.srai c.nop`,
  plus whatever the assembler compresses
- `x0` as destination / source sometimes, `fence`, `nop`

After every block all registers `x1`–`x29` are stored to a dump area, so a mismatch is
located to one block and one register. Signature = 1 KB data area + 40 × 32-word dumps
(1536 words). `x30` / `x31` are the dump pointer and data base and are never randomised.

The same ELF runs on both: Spike starts at `0x8000_0000` (`j _start`) and exits through
`tohost`; on the SoC the boot ROM jumps to `0x8000_0080` (direct boot, back-door preload)
and the program writes the done flag and signature bounds for `tb/tb_random.sv`.

## Step 1 — make the Spike goldens (once, where Spike is installed, e.g. Docker)

```
cd TEST/Test_random
python3 run_spike.py                 # build, run Spike, write golden/*.sig, refresh prebuilt/
python3 run_spike.py --spike /path/to/spike
```
It rebuilds the programs with the compiler found there, runs
`spike --isa=rv32ic -m0x80000000:0x12000 +signature=... +signature-granularity=4`, writes
`golden/rand_<n>.sig` and `golden/rand_<n>.md5`, and copies the exact images Spike ran into
`prebuilt/`. The runners refuse a golden whose `.md5` does not match the images
("golden was made from a different image"), so goldens and images always belong together.

A program that has a Spike golden is never recompiled: `build.py` copies its pinned images
from `prebuilt/` (the ones Spike ran) into `build/`, so a different compiler on another machine
cannot change it. Programs without a golden are compiled. `run_spike.py` recompiles all
(`build.py --rebuild`) and refreshes `golden/` and `prebuilt/` together.

## Step 2 — run the RTL and compare

```
python run_questa.py                 # Questa, CLK_GATING=1 (uses prebuilt/ without a compiler)
python run_questa.py --cg 0
python run_questa.py 3 --gui
python3 run_verilator.py             # Verilator, CLK_GATING 1 and 0
python3 run_verilator.py --quick 3 7
```
A failure prints the first differing word: `data area word <i>` or `block <b>, x<r>`;
open `build/rand_<n>.dis` / `programs/rand_<n>.S` at that block.

## More programs

Add seeds in `tests.py` (`SEEDS`) or change `BLOCKS` / `LENGTH`, then run `run_spike.py` again.

## Result (2026-11-22)

Spike goldens made in the iic-osic-tools Docker container (GCC build, `run_spike.py`).
Every program: 1536 / 1536 signature words equal to Spike, about 4 000 cycles.
- Verilator 5 (Docker): 20 / 20 PASS (10 programs x CLK_GATING 1 and 0)
- Questa 2024.1 (Windows, `prebuilt/` + `golden/` copied from Docker, no Spike or compiler
  needed): 10 / 10 PASS with CLK_GATING 1, 10 / 10 PASS with CLK_GATING 0

**2026-11-22: raised from 10 to 100 programs.** All 100 run to the end on the RTL (Verilator).
rand_1 … rand_10 still match Spike; goldens for rand_11 … rand_100 must be made in Docker:
copy `TEST/Test_random` (scripts + programs) into the Docker copy, run `python3 run_spike.py`,
then copy `golden/` and `prebuilt/` back to Windows.

Questa 2024.1 (Windows, goldens and images from Docker): **100 / 100 PASS** with CLK_GATING 1.
