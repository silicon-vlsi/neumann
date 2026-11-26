# hello.S - the smallest neumann test: add two numbers, write the answer to memory.
# Runs at 0x8000_0080 (the boot ROM jumps here with boot pins = 01, "direct boot").
#
#   answer -> DRAM 0x8001_1000      (the testbench reads it and compares with golden/hello.golden)
#   done   -> DRAM 0x8001_0000 = 0xC0DE0001   ("I am finished")

    .section .text
    .globl _start
_start:
    li   t0, 5              # t0 = 5
    li   t1, 7              # t1 = 7
    add  t2, t0, t1         # t2 = t0 + t1 = 12      <-- the instruction we test
    lui  t3, 0x80011        # t3 = 0x8001_1000  (answer address)
    sw   t2, 0(t3)          # memory[0x8001_1000] = 12
    lui  t4, 0xC0DE0        # t4 = 0xC0DE_0000
    addi t4, t4, 1          # t4 = 0xC0DE_0001  (the "done" code)
    lui  t5, 0x80010        # t5 = 0x8001_0000  (SIG_STATUS address)
    sw   t4, 0(t5)          # memory[0x8001_0000] = 0xC0DE0001
loop:
    j    loop               # stop here forever
