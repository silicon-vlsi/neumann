// crc32.c - bitwise CRC-32 (IEEE, reflected 0xEDB88320) and byte/halfword sums.
// Exercises lbu/lb/lhu/lh/sb/sh, shifts, xor, unaligned byte buffers.
#include "test.h"
#include "crc_inputs.h"

static uint32_t crc32(const volatile uint8_t *p, uint32_t n)
{
  uint32_t c = 0xFFFFFFFFu;
  while (n--) {
    c ^= *p++;
    for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
  }
  return ~c;
}

static uint8_t copy[CRC_N];

uint32_t main(void)
{
  static const char check[] = "123456789";
  uint32_t n = 0, sum8s = 0, sum16 = 0, sum16s = 0;
  RESULT[n++] = crc32((const volatile uint8_t *)check, 9);       // 0xCBF43926
  RESULT[n++] = crc32(crc_in, CRC_N);
  RESULT[n++] = crc32(crc_in + 3, 101);                          // unaligned start/length
  for (uint32_t i = 0; i < CRC_N; i++) sum8s += (uint32_t)(int32_t)(int8_t)crc_in[i];   // lb
  const volatile uint16_t *h = (const volatile uint16_t *)crc_in;
  for (uint32_t i = 0; i < CRC_N / 2; i++) { sum16 += h[i]; sum16s += (uint32_t)(int32_t)(int16_t)h[i]; }
  RESULT[n++] = sum8s;
  RESULT[n++] = sum16;
  RESULT[n++] = sum16s;
  volatile uint8_t *d = copy;                                    // sb then crc of the copy
  for (uint32_t i = 0; i < CRC_N; i++) d[CRC_N - 1 - i] = crc_in[i];
  RESULT[n++] = crc32(copy, CRC_N);
  volatile uint16_t *dh = (volatile uint16_t *)copy;              // sh
  for (uint32_t i = 0; i < CRC_N / 2; i++) dh[i] = (uint16_t)(h[i] ^ 0xA5A5u);
  RESULT[n++] = crc32(copy, CRC_N);
  RESULT_N = n;
  return SIG_PASS;
}
