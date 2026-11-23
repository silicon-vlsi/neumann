// bus.c - bus corner cases: misaligned accesses, bus errors / unmapped addresses,
// address aliasing, ROM writes, and three AHB masters active at once.
//
// Results (RESULT[i], golden/bus.golden):
//  Misaligned loads (core splits them into two bus accesses; no trap):
//   [0] lw +1 0x9A131211  [1] lw +2 0x159A1312  [2] lw +3 0x16159A13
//   [3] lh +1 0x00001211  [4] lh +3 0xFFFF9A13  [5] lhu +3 0x00009A13
//   [6] lw from IRAM at 0x8000_0082 = halves of the two aligned words: 1
//  Misaligned stores (area cleared first, read back as aligned words):
//   [7..10] after sw +5 / sh +11 / sh +3: 0x66000000 0xB2C3D455 0xFF0000A1 0x000000EE
//   [11] traps during the misaligned part: 0
//  Bus errors (unmapped address -> AHB ERROR -> load / store access fault):
//   [12] lw 0x4000_0000: mcause 5   [13] mepc = that instruction: 1
//   [14] sw 0x4000_0000: mcause 7   [15] mepc ok: 1
//   [16] lw 0x1005_0000 (hole between SPI and GPIO): 5
//   [17] lb 0x0000_2000 (just above the boot ROM): 5
//   [18] lw 0x0000_0000: 5
//   [19] lw 0x0000_1FFE (misaligned, 2nd half unmapped): 5   [20] mepc ok: 1
//   [21] faulting load left rd unchanged: 1
//  ROM and aliasing:
//   [22] sw to the boot ROM: traps 0   [23] ROM word unchanged: 1
//   [24] IRAM alias 0x8000_4080 reads 0x8000_0080: 1
//   [25] DRAM alias 0x8001_2040 reads 0x8001_0040: 1
//  Three masters (instruction fetch, core LSU, debug unit) at once:
//   [26] copy / checksum loop iterations while the debug unit was writing > 0: 1
//   [27] loop errors (checksum or copy mismatch): 0
//   [28] words written by the debug unit found intact: 64
//   [29] faults in total: 7
#define TEST_NO_C_TRAP
#include "test.h"

static volatile uint32_t n_trap, t_cause, t_epc;

uint32_t c_trap(uint32_t mcause, uint32_t mepc)
{
  if ((int32_t)mcause < 0) {                    // no interrupts in this test
    SIG_STATUS = 0xBAD0E000u | (mcause & 0xFFFu);
    for (;;) ;
  }
  n_trap++; t_cause = mcause; t_epc = mepc;
  uint16_t h = *(volatile uint16_t *)mepc;      // skip the faulting instruction
  return mepc + (((h & 3) == 3) ? 4 : 2);
}

// load / store at an address, return the faulting pc via a label
#define LOAD(op, addr, out, pc)  __asm__ volatile(".option push\n.option norvc\n" \
    "la %1, 1f\n1: " op " %0, 0(%2)\n.option pop" : "=&r"(out), "=&r"(pc) : "r"(addr) : "memory")
#define STORE(op, addr, val, pc) __asm__ volatile(".option push\n.option norvc\n" \
    "la %0, 1f\n1: " op " %1, 0(%2)\n.option pop" : "=&r"(pc) : "r"(val), "r"(addr) : "memory")

static uint8_t buf[16] __attribute__((aligned(16)));
static uint8_t sbuf[16] __attribute__((aligned(16)));

// three-master part
#define FLAG_START REG32(DRAM_BASE + 0x20)      // core -> testbench: loop running
#define FLAG_DONE  REG32(DRAM_BASE + 0x24)      // testbench (debug unit) -> core: finished
#define DBG_AREA   ((volatile uint32_t *)(DRAM_BASE + 0x1000))   // 64 words written by the debug unit
static uint32_t src[128], dst[128];

int main(void)
{
  uint32_t v, pc;
  n_trap = 0;

  // ---------------------------------------------------------------- misaligned loads
  for (int i = 0; i < 16; i++) buf[i] = 0x10 + i;
  buf[4] = 0x9A;
  LOAD("lw",  buf + 1, v, pc); result(v);
  LOAD("lw",  buf + 2, v, pc); result(v);
  LOAD("lw",  buf + 3, v, pc); result(v);
  LOAD("lh",  buf + 1, v, pc); result(v);
  LOAD("lh",  buf + 3, v, pc); result(v);
  LOAD("lhu", buf + 3, v, pc); result(v);
  {
    uint32_t w0 = REG32(0x80000080), w1 = REG32(0x80000084);
    LOAD("lw", (uint8_t *)0x80000082, v, pc);
    result(v == ((w0 >> 16) | (w1 << 16)));
  }

  // ---------------------------------------------------------------- misaligned stores
  for (int i = 0; i < 16; i++) sbuf[i] = 0;
  STORE("sw", sbuf + 5,  0xA1B2C3D4u, pc);
  STORE("sh", sbuf + 11, 0x0000EEFFu, pc);
  STORE("sh", sbuf + 3,  0x00005566u, pc);
  for (int i = 0; i < 4; i++) result(((volatile uint32_t *)sbuf)[i]);
  result(n_trap);                                // 0

  // ---------------------------------------------------------------- bus errors
  LOAD("lw", (uint32_t *)0x40000000, v, pc);   result(t_cause); result(t_epc == pc);
  STORE("sw", (uint32_t *)0x40000000, 1u, pc); result(t_cause); result(t_epc == pc);
  t_cause = 0; LOAD("lw", (uint32_t *)0x10050000, v, pc); result(t_cause);
  t_cause = 0; LOAD("lb", (uint8_t *)0x00002000, v, pc);  result(t_cause);
  t_cause = 0; LOAD("lw", (uint32_t *)0x00000000, v, pc); result(t_cause);
  t_cause = 0; LOAD("lw", (uint8_t *)0x00001FFE, v, pc);  result(t_cause); result(t_epc == pc);
  {
    uint32_t r = 0x12345678u, a = 0x40000000u;
    __asm__ volatile(".option push\n.option norvc\nlw %0, 0(%1)\n.option pop" : "+r"(r) : "r"(a) : "memory");
    result(r == 0x12345678u);                    // rd not written by the faulting load
  }

  // ---------------------------------------------------------------- ROM write, aliasing
  {
    uint32_t before = REG32(0x00001000), t0 = n_trap;
    STORE("sw", (uint32_t *)0x00001000, 0xFFFFFFFFu, pc);
    result(n_trap - t0);                         // 0
    result(REG32(0x00001000) == before);         // 1
  }
  result(REG32(0x80004080) == REG32(0x80000080));
  result(REG32(0x80012040) == REG32(0x80010040));

  // ---------------------------------------------------------------- three masters
  for (int i = 0; i < 128; i++) src[i] = 0x9E3779B9u * (i + 1);
  uint32_t ref = 0;
  for (int i = 0; i < 128; i++) ref ^= src[i] + i;
  uint32_t iters = 0, errs = 0;
  FLAG_DONE = 0;
  FLAG_START = 0x5741u;
  while (FLAG_DONE != 0xD0Eu && iters < 100000) {
    uint32_t s = 0;
    for (int i = 0; i < 128; i++) { dst[i] = src[i]; s ^= dst[i] + i; }
    if (s != ref) errs++;
    for (int i = 0; i < 128; i += 17) if (dst[i] != src[i]) errs++;
    iters++;
  }
  result(iters > 0 && FLAG_DONE == 0xD0Eu);      // 1
  result(errs);                                  // 0
  {
    uint32_t ok = 0;
    for (int i = 0; i < 64; i++) if (DBG_AREA[i] == (0xDB000000u | (i * 0x01010101u & 0x00FFFFFFu))) ok++;
    result(ok);                                  // 64
  }
  result(n_trap);                                // 7
  return SIG_PASS;
}
