// sieve.c - sieve of Eratosthenes below SIEVE_N (byte array in .bss, additions only).
// Results: number of primes, sum of primes, largest prime, primes [0..7], primes [-4..-1].
#include "test.h"

#define SIEVE_N 2048
static uint8_t composite[SIEVE_N];
static uint32_t primes[400];

uint32_t main(void)
{
  uint32_t np = 0, sum = 0;
  for (uint32_t i = 2; i < SIEVE_N; i++) {
    if (composite[i]) continue;
    primes[np++] = i;
    sum += i;
    for (uint32_t j = i + i; j < SIEVE_N; j += i) composite[j] = 1;
  }
  uint32_t n = 0;
  RESULT[n++] = np;
  RESULT[n++] = sum;
  RESULT[n++] = primes[np - 1];
  for (uint32_t i = 0; i < 8; i++) RESULT[n++] = primes[i];
  for (uint32_t i = np - 4; i < np; i++) RESULT[n++] = primes[i];
  RESULT_N = n;
  return SIG_PASS;
}
