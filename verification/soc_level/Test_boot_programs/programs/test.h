// test.h - common definitions for the boot test programs.
// Results: RESULT[i] = DRAM 0x8001_1C00 + 4 i (max 64 words), count RESULT_N = 0x8001_1BFC.
// Done:    SIG_STATUS = 0x8001_0000 = 0xC0DE0001 (start.S writes main()'s return value).
// Trap:    SIG_STATUS = 0xBAD0F000 | mcause (unexpected exception or interrupt).
// Memory:  .data/.bss must end below 0x8001_1BFC (build.py checks), stack top 0x8001_2000.
#pragma once
#include "soc.h"

#define RESULT_N  REG32(DRAM_BASE + 0x1BFC)
#define RESULT    ((volatile uint32_t *)(DRAM_BASE + 0x1C00))
#define RESULT_MAX 64

#ifndef TEST_NO_C_TRAP
// start.S trap entry calls this; any trap in these programs is an error
uint32_t c_trap(uint32_t mcause, uint32_t mepc)
{
  (void)mepc;
  SIG_STATUS = 0xBAD0F000u | (mcause & 0xFFFu);
  for (;;) ;
}
#endif
