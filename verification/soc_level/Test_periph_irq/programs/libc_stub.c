// libc_stub.c - the few runtime helpers the programs / FreeRTOS need, since they are linked
// with -nostdlib (no libc, no libgcc): memset/memcpy/memmove/memcmp and RV32I (no M)
// multiply / divide helpers that the compiler may call. Volatile pointers stop the compiler
// from turning these loops back into calls to themselves.
#include <stddef.h>
#include <stdint.h>

void *memset(void *d, int c, size_t n)
{ volatile uint8_t *p = d; while (n--) *p++ = (uint8_t)c; return d; }

void *memcpy(void *d, const void *s, size_t n)
{ volatile uint8_t *p = d; const volatile uint8_t *q = s; while (n--) *p++ = *q++; return d; }

void *memmove(void *d, const void *s, size_t n)
{
  volatile uint8_t *p = d; const volatile uint8_t *q = s;
  if (p < q) while (n--) *p++ = *q++;
  else { p += n; q += n; while (n--) *--p = *--q; }
  return d;
}

int memcmp(const void *a, const void *b, size_t n)
{
  const volatile uint8_t *p = a, *q = b;
  for (; n; n--, p++, q++) if (*p != *q) return *p < *q ? -1 : 1;
  return 0;
}

uint32_t __mulsi3(uint32_t a, uint32_t b)
{ uint32_t r = 0; while (b) { if (b & 1u) r += a; a <<= 1; b >>= 1; } return r; }

uint64_t __muldi3(uint64_t a, uint64_t b)          // 64-bit multiply (shift by 1 only)
{ uint64_t r = 0; while (b) { if (b & 1u) r += a; a <<= 1; b >>= 1; } return r; }

static uint32_t udivmod(uint32_t n, uint32_t d, uint32_t *rem)
{
  uint32_t q = 0, r = 0;
  if (d == 0) { *rem = n; return 0xFFFFFFFFu; }         // RISC-V divide-by-zero results
  for (int i = 31; i >= 0; i--) { r = (r << 1) | ((n >> i) & 1u); if (r >= d) { r -= d; q |= 1u << i; } }
  *rem = r;
  return q;
}
uint32_t __udivsi3(uint32_t n, uint32_t d) { uint32_t r; return udivmod(n, d, &r); }
uint32_t __umodsi3(uint32_t n, uint32_t d) { uint32_t r; udivmod(n, d, &r); return r; }
int32_t __divsi3(int32_t n, int32_t d)
{
  uint32_t r, q = udivmod(n < 0 ? 0u - (uint32_t)n : (uint32_t)n, d < 0 ? 0u - (uint32_t)d : (uint32_t)d, &r);
  return ((n < 0) != (d < 0)) ? (int32_t)(0u - q) : (int32_t)q;
}
int32_t __modsi3(int32_t n, int32_t d)
{
  uint32_t r;
  udivmod(n < 0 ? 0u - (uint32_t)n : (uint32_t)n, d < 0 ? 0u - (uint32_t)d : (uint32_t)d, &r);
  return n < 0 ? (int32_t)(0u - r) : (int32_t)r;
}
