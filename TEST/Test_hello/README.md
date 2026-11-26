# Test_hello — the smallest neumann test

This test adds 5 + 7 and checks that the chip gets 12. That is all it does.

It uses the **same 4 steps as every other suite**, with nothing else around them. Once this one is clear, every other suite is the same idea with a bigger program.

```
1. put the program in the chip     prebuilt/hello_iram.hex  ->  IRAM
2. let it run                      until DRAM 0x8001_0000 = 0xC0DE0001 ("done")
3. read the answer                 DRAM 0x8001_1000
4. compare with the answer key     golden/hello.golden  ->  RESULT: PASS / FAIL
```

## Run it

```
cd TEST\Test_hello
python run_questa.py          # Questa (Windows / Linux)
python run_questa.py --gui    # with waves
python3 run_verilator.py      # Verilator (Linux / Docker)
```

What you see:
```
step 1: loaded TEST/Test_hello/prebuilt/hello_iram.hex into IRAM
step 2: program finished at cycle 47 (SIG_STATUS = c0de0001)
step 3: chip answer   = 0000000c (12)
step 4: golden answer = 0000000c (12)
RESULT: PASS
PASSED 1 / 1
```

The test needs no RISC-V compiler. The 10 instructions are encoded by `programs/mkhex.py`.

## The 5 files

| File | What it is |
|---|---|
| `programs/hello.S` | the program, 10 instructions (readable source) |
| `programs/mkhex.py` | turns those 10 instructions into machine code → `prebuilt/hello_iram.hex` |
| `programs/gen_golden.py` | the answer key: Python computes `5 + 7` → `golden/hello.golden` |
| `tb/tb_hello.sv` | the testbench: chip + the 4 steps |
| `run_questa.py` / `run_verilator.py` | run everything, print `PASSED 1 / 1` |

## Step 0 — the program (`programs/hello.S`)

```asm
_start:                     # 0x8000_0080: the boot ROM jumps here
    li   t0, 5              # t0 = 5
    li   t1, 7              # t1 = 7
    add  t2, t0, t1         # t2 = 12            <-- the instruction we test
    lui  t3, 0x80011        # t3 = 0x8001_1000   (answer address)
    sw   t2, 0(t3)          # memory[0x8001_1000] = 12
    lui  t4, 0xC0DE0
    addi t4, t4, 1          # t4 = 0xC0DE0001    ("done" code)
    lui  t5, 0x80010        # t5 = 0x8001_0000   (SIG_STATUS)
    sw   t4, 0(t5)          # memory[0x8001_0000] = 0xC0DE0001
loop: j loop                # stop
```

The chip has no screen and no `printf`, so a program can only report by **writing to memory**. Two addresses are agreed in advance:
- the answer goes to `0x8001_1000`;
- "I am finished" (`0xC0DE0001`) goes to `0x8001_0000`.

## Step 0b — machine code (`programs/mkhex.py`)

The CPU reads numbers, not text. `mkhex.py` turns each line of `hello.S` into its 32-bit RISC-V code:

```
0x80000080: 00500293   li   t0, 5          (addi x5, x0, 5)
0x80000084: 00700313   li   t1, 7
0x80000088: 006283b3   add  t2, t0, t1
0x8000008c: 80011e37   lui  t3, 0x80011
0x80000090: 007e2023   sw   t2, 0(t3)
0x80000094: c0de0eb7   lui  t4, 0xC0DE0
0x80000098: 001e8e93   addi t4, t4, 1
0x8000009c: 80010f37   lui  t5, 0x80010
0x800000a0: 01df2023   sw   t4, 0(t5)
0x800000a4: 0000006f   j    loop
```

`prebuilt/hello_iram.hex` has one word per line, starting at `0x8000_0000`. The program begins at `0x8000_0080`, so the file starts with 32 lines of `00000000`.

The bigger suites use the RISC-V GCC toolchain to do this step for C programs.

## Step 0c — the answer key (`programs/gen_golden.py`)

```python
answer = 5 + 7                       # computed by Python, NOT by our chip
f.write('%08x\n' % answer)           # -> golden/hello.golden = 0000000c
```

The answer key must come from somewhere other than the chip, otherwise we would compare the chip with itself.

## Steps 1–4 — the testbench (`tb/tb_hello.sv`)

**Set up.** A 100 MHz clock, then the chip with boot pins `01` (direct boot, so the boot ROM jumps straight to `0x8000_0080`):
```systemverilog
always #5 clk = ~clk;
wire [31:0] gpio_i = {2'b01, 30'b0};
neumann_soc dut (...);
```

**Step 1 — load the program.** The testbench writes straight into the memory arrays inside the chip ("back-door"):
```systemverilog
`define IRAM dut.u_uncore.ram.ram.memory.ram.RAM
$readmemh(rom_file,  `ROM);          // boot ROM program
$readmemh(iram_file, `IRAM);         // our program
```

**Step 2 — run.** Release reset and wait for the "done" code:
```systemverilog
rst_n = 1;
while (dram('h0000) != 32'hC0DE0001 && cyc < 10000) @(posedge clk);
```
It takes about 47 clocks: the boot ROM reads the pins and jumps, then our 10 instructions run. If "done" never comes, the test prints `RESULT: FAIL`.

**Step 3 — read the answer:**
```systemverilog
answer = dram('h1000);               // DRAM 0x8001_1000
```

**Step 4 — compare with the answer key:**
```systemverilog
$fscanf(fd, "%h", expected);         // golden/hello.golden
if (answer === expected) $display("RESULT: PASS");
else                     $display("RESULT: FAIL");
```

`run_questa.py` then looks for `RESULT: PASS` in the log and prints `PASSED 1 / 1`.

## Try it: make it fail on purpose

1. Open `golden/hello.golden` and change `0000000c` to `0000000d`.
2. Run `vsim` by hand. Don't use `run_questa.py`, because it rewrites the golden file first.
3. You will see:
   ```
   step 3: chip answer   = 0000000c (12)
   step 4: golden answer = 0000000d (13)
   RESULT: FAIL
   ```

This proves the check really compares. A test that can never fail proves nothing.

You can also break the program instead: in `mkhex.py`, change `i_type(7, ...)` to `i_type(8, ...)`. The chip answers 13, so the test fails.

## How the big suites map onto these same 4 steps

| | Test_hello | Big suites |
|---|---|---|
| program | 10 instructions | C programs, official tests, 100 random programs, FreeRTOS |
| machine code | `mkhex.py` | RISC-V GCC (or `prebuilt/`) |
| step 1, load | `$readmemh` into IRAM | same, or via SPI flash / debug UART |
| step 2, run | wait for `0xC0DE0001` | same |
| step 3, read | 1 word | 32 words … 1536 words (signature) |
| step 4, answer key | Python `5 + 7` | Python, RISC-V International references, Spike |
