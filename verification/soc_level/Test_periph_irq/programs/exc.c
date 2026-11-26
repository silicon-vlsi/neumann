// exc.c - synchronous exceptions: exact mcause / mepc, mstatus stacking, mret, CSR edges.
//
// The handler (c_trap, called from start.S) records mcause, mepc and mstatus as seen inside
// the trap and returns mepc + the length of the faulting instruction (2 or 4 bytes).
//
// Results (RESULT[i], golden/exc.golden):
//  ecall, MIE = 0 before:   [0] mcause 11   [1] mepc = the ecall: 1   [2] mstatus in trap 0x1800
//                           (MPP = M, MPIE = 0, MIE = 0)
//  ecall, MIE = 1 before:   [3] mstatus in trap 0x1880 (MPIE = 1, MIE = 0)
//                           [4] mstatus after mret 0x1888 (MIE restored, MPIE = 1)
//  illegal 32-bit 0xFFFFFFFF:         [5] mcause 2  [6] mepc ok 1
//  illegal 16-bit 0x0000:             [7] mcause 2  [8] mepc ok 1
//  mul (M extension not present):     [9] mcause 2  [10] mepc ok 1
//  c.jr x0 (reserved, 0x8002):        [11] mcause 2 [12] mepc ok 1
//  after each trap execution continued at the next instruction: [13] 1
//  CSRs not implemented on this core (errata): mscratch write/read, no trap: [14] value 0
//                                              [15] mtval reads 0   [16] traps for both: 0
//  mepc write/read: [17] 0x80000124   mcause write 0x8000001F / 0x12345678 -> [18] 0x8000001F
//  [19] 0x00000018 (only bit 31 and bits 4:0 exist)   mtvec: [20] 0x80000000
//  [21] traps in total: 6
#define TEST_NO_C_TRAP
#include "test.h"

static volatile uint32_t n_trap, t_cause, t_epc, t_status;

uint32_t c_trap(uint32_t mcause, uint32_t mepc)
{
  uint32_t st;
  __asm__ volatile("csrr %0, mstatus" : "=r"(st));
  if ((int32_t)mcause < 0) {                     // no interrupts in this test
    SIG_STATUS = 0xBAD0E000u | (mcause & 0xFFFu);
    for (;;) ;
  }
  n_trap++; t_cause = mcause; t_epc = mepc; t_status = st;
  uint16_t h = *(volatile uint16_t *)mepc;
  return mepc + (((h & 3) == 3) ? 4 : 2);
}

// run one instruction sequence that traps; pc = address of the trapping instruction
#define TRAP(code, pc) __asm__ volatile(".option push\n.option norvc\nla %0, 1f\n.option pop\n1: " code \
                                        : "=&r"(pc) :: "memory")

int main(void)
{
  uint32_t pc, after;
  timer_off();
  n_trap = 0;

  // ---------------------------------------------------------------- ecall
  mie_off();
  TRAP("ecall\n", pc);
  result(t_cause); result(t_epc == pc); result(t_status & 0x1888);
  mie_on();                                      // no interrupt source is enabled
  TRAP("ecall\n", pc);
  __asm__ volatile("csrr %0, mstatus" : "=r"(after));
  mie_off();
  result(t_status & 0x1888); result(after & 0x1888);

  // ---------------------------------------------------------------- illegal instructions
  uint32_t cont = 0, marker;
  TRAP(".option push\n.option norvc\n.word 0xFFFFFFFF\n.option pop\n", pc);
  result(t_cause); result(t_epc == pc);
  TRAP(".hword 0x0000\n.balign 4\n", pc);
  result(t_cause); result(t_epc == pc);
  TRAP(".option push\n.option norvc\n.word 0x023100B3\n.option pop\n", pc);   // mul x1, x2, x3
  result(t_cause); result(t_epc == pc);
  marker = 0;
  __asm__ volatile(".option push\n.option norvc\nla %0, 1f\n.option pop\n"
                   "1: .hword 0x8002\n.balign 4\nli %1, 0x5A\n" : "=&r"(pc), "=&r"(marker) :: "memory");
  result(t_cause); result(t_epc == pc);
  cont = (marker == 0x5A);                       // the instruction after the trap ran
  result(cont);

  // ---------------------------------------------------------------- CSR edges
  uint32_t t0 = n_trap, v;
  __asm__ volatile("csrw 0x340, %0" :: "r"(0x12345678u));          // mscratch
  __asm__ volatile("csrr %0, 0x340" : "=r"(v));  result(v);
  __asm__ volatile("csrr %0, 0x343" : "=r"(v));  result(v);         // mtval
  result(n_trap - t0);
  __asm__ volatile("csrw mepc, %0" :: "r"(0x80000124u));
  __asm__ volatile("csrr %0, mepc" : "=r"(v));   result(v);
  __asm__ volatile("csrw mcause, %0" :: "r"(0x8000001Fu));
  __asm__ volatile("csrr %0, mcause" : "=r"(v)); result(v);
  __asm__ volatile("csrw mcause, %0" :: "r"(0x12345678u));
  __asm__ volatile("csrr %0, mcause" : "=r"(v)); result(v);
  __asm__ volatile("csrr %0, mtvec" : "=r"(v));  result(v);
  result(n_trap);
  return SIG_PASS;
}
