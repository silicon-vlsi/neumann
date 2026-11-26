#!/usr/bin/env python3
"""mkhex.py - turns programs/hello.S into prebuilt/hello_iram.hex WITHOUT a RISC-V compiler.

The 10 instructions of hello.S are encoded here by hand (RISC-V base formats), so the test
runs on any PC with Questa only. One 32-bit word per line, word 0 = address 0x8000_0000.
The program starts at 0x8000_0080, so the first 32 words are 0.
"""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
T0, T1, T2, T3, T4, T5 = 5, 6, 7, 28, 29, 30        # register numbers of t0..t5


def i_type(imm, rs1, f3, rd, op): return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def r_type(f7, rs2, rs1, f3, rd, op): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def u_type(imm20, rd, op): return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op
def s_type(imm, rs2, rs1, f3, op):
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op
def jal(off, rd):
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
           (((o >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F

prog = [
    ('li   t0, 5',        i_type(5, 0, 0, T0, 0x13)),          # addi t0, x0, 5
    ('li   t1, 7',        i_type(7, 0, 0, T1, 0x13)),          # addi t1, x0, 7
    ('add  t2, t0, t1',   r_type(0, T1, T0, 0, T2, 0x33)),
    ('lui  t3, 0x80011',  u_type(0x80011, T3, 0x37)),
    ('sw   t2, 0(t3)',    s_type(0, T2, T3, 2, 0x23)),
    ('lui  t4, 0xC0DE0',  u_type(0xC0DE0, T4, 0x37)),
    ('addi t4, t4, 1',    i_type(1, T4, 0, T4, 0x13)),
    ('lui  t5, 0x80010',  u_type(0x80010, T5, 0x37)),
    ('sw   t4, 0(t5)',    s_type(0, T4, T5, 2, 0x23)),
    ('j    loop',         jal(0, 0)),                          # jal x0, 0 = jump to itself
]

out = os.path.join(HERE, '..', 'prebuilt', 'hello_iram.hex')
with open(out, 'w', newline='\n') as f:
    for _ in range(32):                   # 0x8000_0000 .. 0x8000_007C: unused
        f.write('00000000\n')
    for _, w in prog:
        f.write('%08x\n' % w)
for i, (txt, w) in enumerate(prog):
    print('  0x%08x: %08x   %s' % (0x80000080 + 4 * i, w, txt))
print('wrote', os.path.normpath(out))
