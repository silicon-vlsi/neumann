// gcd.c - binary GCD (Stein) over the pairs in gcd_inputs.h (.data -> DRAM).
#include "test.h"
#include "gcd_inputs.h"

static uint32_t gcd(uint32_t a, uint32_t b)
{
  unsigned k = 0;
  if (a == 0) return b;
  if (b == 0) return a;
  while (((a | b) & 1u) == 0) { a >>= 1; b >>= 1; k++; }
  while ((a & 1u) == 0) a >>= 1;
  do {
    while ((b & 1u) == 0) b >>= 1;
    if (a > b) { uint32_t t = a; a = b; b = t; }
    b -= a;
  } while (b != 0);
  return a << k;
}

uint32_t main(void)
{
  for (int i = 0; i < GCD_N; i++) RESULT[i] = gcd(gcd_in[i][0], gcd_in[i][1]);
  RESULT_N = GCD_N;
  return SIG_PASS;
}
