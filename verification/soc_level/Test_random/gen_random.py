#!/usr/bin/env python3
"""gen_random.py - random RV32IC instruction-stream generator (assembly source).

usage:  python gen_random.py --seed 7 [--blocks 40] [--len 25] [-o programs/rand_7.S]

The program is the same for the RTL and for Spike: the same ELF runs on both, and the
signature (memory from begin_signature to end_signature) is compared word by word.

Layout (sw/app/link_app.ld):
  0x8000_0000  j _start           (Spike starts here; the SoC boot ROM jumps to +0x80)
  0x8000_0080  _start: init x1..x29 with random values, x31 = data area + 512,
               x30 = register-dump area; then <blocks> blocks of <len> random
               instructions, each followed by a dump of x1..x29 (32 words per block)
  .data        begin_signature: 1 KB random data (loads / stores use it) | dumps | end_signature
  end:         SIG_STATUS / signature bounds for the RTL testbench, then tohost = 1 (Spike exits)
Registers: x1..x29 random; x30 = dump pointer, x31 = data base (never written randomly).
Instructions: RV32I ALU (reg / imm / shifts), lui, auipc, lb lh lw lbu lhu sb sh sw
(aligned, +-512 bytes around x31), all six branches and jal / jalr (forward, taken or not
by the random data), and explicit RVC forms (c.addi c.li c.lui c.mv c.add c.sub c.xor c.or
c.and c.andi c.slli c.srli c.srai c.beqz c.bnez c.j c.jal c.nop). The assembler also
compresses eligible 32-bit instructions (.option rvc).
"""
import argparse, random

POOL = list(range(1, 30))                 # x1..x29
CREG = list(range(8, 16))                 # registers usable by most RVC forms
EDGE32 = [0, 1, -1, 0x7FFFFFFF, 0x80000000, 0x80000001, 0xFFFF, 0x10000, 0x55555555, 0xAAAAAAAA]
EDGE12 = [0, 1, -1, 2047, -2048, 0x7FF, -0x800 + 1]


class Gen:
    def __init__(self, seed, blocks, length):
        self.r = random.Random(seed)
        self.seed, self.blocks, self.length = seed, blocks, length
        self.out = []
        self.lbl = 0

    def x(self, n):
        return 'x%d' % n

    def reg(self, c=False):
        return self.x(self.r.choice(CREG if c else POOL))

    def src(self):                        # sources may also be x0
        return 'x0' if self.r.random() < 0.06 else self.reg()

    def dst(self):                        # rd = x0 sometimes (result discarded)
        return 'x0' if self.r.random() < 0.04 else self.reg()

    def imm12(self):
        return self.r.choice(EDGE12) if self.r.random() < 0.2 else self.r.randint(-2048, 2047)

    def val32(self):
        v = self.r.choice(EDGE32) if self.r.random() < 0.25 else self.r.getrandbits(32)
        return v & 0xFFFFFFFF

    def label(self):
        self.lbl += 1
        return 'L%d' % self.lbl

    def emit(self, s):
        self.out.append('    ' + s)

    # ---- straight-line instructions (no control flow)
    def straight(self):
        r = self.r
        k = r.choices(['rr', 'ri', 'sh', 'lui', 'auipc', 'ld', 'st', 'c'], [25, 22, 8, 4, 3, 10, 8, 14])[0]
        if k == 'rr':
            op = r.choice(['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and'])
            self.emit('%s %s, %s, %s' % (op, self.dst(), self.src(), self.src()))
        elif k == 'ri':
            op = r.choice(['addi', 'slti', 'sltiu', 'xori', 'ori', 'andi'])
            self.emit('%s %s, %s, %d' % (op, self.dst(), self.src(), self.imm12()))
        elif k == 'sh':
            op = r.choice(['slli', 'srli', 'srai'])
            sh = r.choice([0, 1, 31, r.randint(0, 31)])
            self.emit('%s %s, %s, %d' % (op, self.dst(), self.src(), sh))
        elif k == 'lui':
            self.emit('lui %s, 0x%x' % (self.dst(), r.getrandbits(20)))
        elif k == 'auipc':
            self.emit('auipc %s, 0x%x' % (self.dst(), r.getrandbits(20)))
        elif k == 'ld':
            op, sz = r.choice([('lb', 1), ('lbu', 1), ('lh', 2), ('lhu', 2), ('lw', 4)])
            off = r.randrange(-512, 512 - sz + 1, sz)
            self.emit('%s %s, %d(x31)' % (op, self.dst(), off))
        elif k == 'st':
            op, sz = r.choice([('sb', 1), ('sh', 2), ('sw', 4)])
            off = r.randrange(-512, 512 - sz + 1, sz)
            self.emit('%s %s, %d(x31)' % (op, self.src(), off))
        else:
            self.rvc()

    def rvc(self):
        r = self.r
        k = r.choice(['addi', 'li', 'lui', 'mv', 'add', 'sub', 'xor', 'or', 'and', 'andi',
                      'slli', 'srli', 'srai', 'nop'])
        nz6 = lambda: r.choice([i for i in range(-32, 32) if i != 0])
        if k == 'addi':
            self.emit('c.addi %s, %d' % (self.reg(), nz6()))
        elif k == 'li':
            self.emit('c.li %s, %d' % (self.reg(), r.randint(-32, 31)))
        elif k == 'lui':
            rd = r.choice([n for n in POOL if n != 2])          # rd != x0, x2
            self.emit('c.lui x%d, 0x%x' % (rd, r.choice(list(range(1, 32)) + list(range(0xFFFE0, 0x100000)))))
        elif k == 'mv':
            self.emit('c.mv %s, %s' % (self.reg(), self.reg()))
        elif k == 'add':
            self.emit('c.add %s, %s' % (self.reg(), self.reg()))
        elif k in ('sub', 'xor', 'or', 'and'):
            self.emit('c.%s %s, %s' % (k, self.reg(True), self.reg(True)))
        elif k == 'andi':
            self.emit('c.andi %s, %d' % (self.reg(True), r.randint(-32, 31)))
        elif k == 'slli':
            self.emit('c.slli %s, %d' % (self.reg(), r.randint(1, 31)))
        elif k in ('srli', 'srai'):
            self.emit('c.%s %s, %d' % (k, self.reg(True), r.randint(1, 31)))
        else:
            self.emit('c.nop')

    def skip_body(self):
        for _ in range(self.r.randint(1, 3)):
            self.straight()

    # ---- one instruction slot (may be a small forward control-flow construct)
    def slot(self):
        r = self.r
        k = r.choices(['s', 'br', 'cbr', 'jal', 'cj', 'jalr', 'fence'], [80, 8, 3, 2, 2, 2, 1])[0]
        if k == 's':
            self.straight()
        elif k == 'br':
            L = self.label()
            op = r.choice(['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'])
            a, b = self.src(), self.src()
            if r.random() < 0.15:
                b = a                                            # equal operands
            self.emit('%s %s, %s, %s' % (op, a, b, L))
            self.skip_body()
            self.out.append(L + ':')
        elif k == 'cbr':
            L = self.label()
            self.emit('c.%s %s, %s' % (r.choice(['beqz', 'bnez']), self.reg(True), L))
            self.skip_body()
            self.out.append(L + ':')
        elif k == 'jal':
            L = self.label()
            self.emit('jal %s, %s' % (self.dst(), L))
            self.skip_body()
            self.out.append(L + ':')
        elif k == 'cj':
            L = self.label()
            self.emit('%s %s' % (r.choice(['c.j', 'c.jal']), L))
            self.skip_body()
            self.out.append(L + ':')
        elif k == 'jalr':
            L = self.label()
            t = self.reg()
            self.emit('la %s, %s' % (t, L))
            self.emit('jalr %s, 0(%s)' % (self.dst(), t))
            self.skip_body()
            self.out.append(L + ':')
        else:
            self.emit(r.choice(['fence', 'nop']))

    def program(self):
        o = self.out
        o += ['// rand_%d.S - generated by gen_random.py --seed %d --blocks %d --len %d'
              % (self.seed, self.seed, self.blocks, self.length),
              '    .option rvc',
              '    .section .vectors, "ax"',
              '    .globl _vectors',
              '_vectors:',
              '    .option push', '    .option norvc',
              '    j _start                  # 0x8000_0000: Spike starts here',
              '    .option pop',
              '    .org 0x80',
              '    .globl _start',
              '_start:                       # 0x8000_0080: the SoC boot ROM jumps here',
              '    la x31, data_area + 512',
              '    la x30, dump_area']
        for n in POOL:
            self.emit('li x%d, 0x%08x' % (n, self.val32()))
        for blk in range(self.blocks):
            o.append('// ---- block %d' % blk)
            for _ in range(self.length):
                self.slot()
            for n in POOL:
                self.emit('sw x%d, %d(x30)' % (n, 4 * (n - 1)))
            self.emit('addi x30, x30, 128')
        o += ['// ---- end: signature bounds + done flag for the RTL testbench, tohost for Spike',
              '    la x1, begin_signature', '    li x2, 0x80010010', '    sw x1, 0(x2)',
              '    la x1, end_signature', '    sw x1, 4(x2)',
              '    li x1, 0xC0DE0001', '    li x2, 0x80010000', '    sw x1, 0(x2)',
              '    li x1, 1', '    la x2, tohost', '    sw x1, 0(x2)', '    sw x0, 4(x2)',
              'end_loop:', '    j end_loop',
              '',
              '    .data',
              '    .balign 16',
              '    .globl begin_signature',
              'begin_signature:',
              'data_area:']
        for i in range(0, 256, 4):
            o.append('    .word ' + ', '.join('0x%08x' % self.val32() for _ in range(4)))
        o += ['dump_area:',
              '    .fill %d, 4, 0' % (32 * self.blocks),
              '    .balign 16',
              '    .globl end_signature',
              'end_signature:',
              '    .balign 8',
              '    .globl tohost',
              'tohost:   .dword 0',
              '    .globl fromhost',
              'fromhost: .dword 0',
              '']
        return '\n'.join(o)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seed', type=int, required=True)
    ap.add_argument('--blocks', type=int, default=40)
    ap.add_argument('--len', type=int, default=25)
    ap.add_argument('-o', '--out')
    a = ap.parse_args()
    text = Gen(a.seed, a.blocks, a.len).program()
    with open(a.out or 'programs/rand_%d.S' % a.seed, 'w') as f:
        f.write(text)


if __name__ == '__main__':
    main()
