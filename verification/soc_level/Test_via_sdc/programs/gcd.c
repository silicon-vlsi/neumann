// gcd.c - neumann SoC test program for the SDC flash boot.
// Loaded from the SPI flash on the SDC port by the boot ROM:
//   code (.text)          -> IRAM 0x8000_0000
//   input pairs (.data)   -> DRAM 0x8001_0040   (also checks the DRAM part of the copy)
// Writes gcd(a, b) of every pair to RESULT[i] (DRAM 0x8001_1000 + 4 i), the pair count to
// RESULT_N, then returns SIG_PASS -> start.S writes it to SIG_STATUS (DRAM 0x8001_0000).
// The testbench compares RESULT[] with golden/gcd.golden.
// Binary GCD (Stein): shifts, subtracts and compares only (RV32I, no M extension).
#include "soc.h"
#include "gcd_inputs.h"

#define RESULT_N  REG32(DRAM_BASE + 0x0FFC)
#define RESULT    ((volatile uint32_t *)(DRAM_BASE + 0x1000))

static uint32_t gcd(uint32_t a, uint32_t b)
{
  unsigned k = 0;
  if (a == 0) return b;
  if (b == 0) return a;
  while (((a | b) & 1u) == 0) { a >>= 1; b >>= 1; k++; }   // common factors of 2
  while ((a & 1u) == 0) a >>= 1;
  do {
    while ((b & 1u) == 0) b >>= 1;
    if (a > b) { uint32_t t = a; a = b; b = t; }
    b -= a;
  } while (b != 0);
  return a << k;
}

// start.S trap entry calls this; any trap here is an error
uint32_t c_trap(uint32_t mcause, uint32_t mepc)
{
  (void)mepc;
  SIG_STATUS = 0xBAD0F000u | (mcause & 0xFFFu);
  for (;;) ;
}

uint32_t main(void)
{
  for (int i = 0; i < GCD_N; i++)
    RESULT[i] = gcd(gcd_in[i][0], gcd_in[i][1]);
  RESULT_N = GCD_N;
  return SIG_PASS;
}
