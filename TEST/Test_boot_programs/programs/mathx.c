// mathx.c - software multiply / divide (shift-add, restoring division; the core has no M
// extension) and Fibonacci. Results: 8 products (low 32 bits), 8 quotients + 8 remainders,
// fib(47), 64-bit product of two 32-bit values (hi, lo).
#include "test.h"
#include "mathx_inputs.h"

static uint32_t mul32(uint32_t a, uint32_t b)
{
  uint32_t r = 0;
  while (b) { if (b & 1u) r += a; a <<= 1; b >>= 1; }
  return r;
}

static uint32_t divu(uint32_t n, uint32_t d, uint32_t *rem)
{
  uint32_t q = 0, r = 0;
  for (int i = 31; i >= 0; i--) {
    r = (r << 1) | ((n >> i) & 1u);
    if (r >= d) { r -= d; q |= 1u << i; }
  }
  *rem = r;
  return q;
}

static void mul64(uint32_t a, uint32_t b, uint32_t *hi, uint32_t *lo)
{
  uint32_t ah = 0, al = a, rh = 0, rl = 0;
  while (b) {
    if (b & 1u) { uint32_t t = rl + al; rh += ah + (t < rl); rl = t; }
    ah = (ah << 1) | (al >> 31); al <<= 1; b >>= 1;
  }
  *hi = rh; *lo = rl;
}

uint32_t main(void)
{
  uint32_t n = 0, r, hi, lo;
  for (int i = 0; i < 8; i++) RESULT[n++] = mul32(mul_in[i][0], mul_in[i][1]);
  for (int i = 0; i < 8; i++) { RESULT[n++] = divu(div_in[i][0], div_in[i][1], &r); RESULT[n++] = r; }
  uint32_t f0 = 0, f1 = 1;
  for (int i = 0; i < 46; i++) { uint32_t t = f0 + f1; f0 = f1; f1 = t; }
  RESULT[n++] = f1;                                   // fib(47) = 2971215073
  mul64(mul_in[7][0], mul_in[7][1], &hi, &lo);
  RESULT[n++] = hi;
  RESULT[n++] = lo;
  RESULT_N = n;
  return SIG_PASS;
}
