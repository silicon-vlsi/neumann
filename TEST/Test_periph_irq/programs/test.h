// test.h - common definitions for the interrupt / peripheral test programs.
// Results: RESULT[i] = DRAM 0x8001_1C00 + 4 i (max 64 words), count RESULT_N = 0x8001_1BFC.
// Done:    SIG_STATUS = 0x8001_0000 = 0xC0DE0001 (start.S writes main()'s return value).
// Each program has its own c_trap(); an unexpected trap writes 0xBAD0F000 | mcause.
#pragma once
#include "soc.h"

#define RESULT_N  REG32(DRAM_BASE + 0x1BFC)
#define RESULT    ((volatile uint32_t *)(DRAM_BASE + 0x1C00))
#define RESULT_MAX 64

#define UART_IIR  REG8(UART_BASE + 2)
#define UART_FCR  REG8(UART_BASE + 2)
#define UART_MCR  REG8(UART_BASE + 4)

#define GPIO_FALL_IE  REG32(GPIO_BASE + 0x20)
#define GPIO_FALL_IP  REG32(GPIO_BASE + 0x24)
#define GPIO_HIGH_IE  REG32(GPIO_BASE + 0x28)
#define GPIO_HIGH_IP  REG32(GPIO_BASE + 0x2C)
#define GPIO_LOW_IE   REG32(GPIO_BASE + 0x30)
#define GPIO_LOW_IP   REG32(GPIO_BASE + 0x34)

#define SPI_TXMARK 0x50
#define SPI_SCKMODE 0x04

#define TIMEOUT   0xDEAD0000u      // recorded when a wait loop times out

static uint32_t rn;                // number of results written
static inline void result(uint32_t v) { if (rn < RESULT_MAX) RESULT[rn] = v; rn++; RESULT_N = rn; }

static inline void mie_on(void)  { __asm__ volatile("csrsi mstatus, 8" ::: "memory"); }
static inline void mie_off(void) { __asm__ volatile("csrci mstatus, 8" ::: "memory"); }

static inline uint32_t now(void) { return CLINT_MTIME; }      // mtime low word, 1 per clock
static inline void delay(uint32_t cyc) { uint32_t t = now(); while (now() - t < cyc) ; }

// mtimecmp: high word to all ones first so no spurious match while the low word changes
static inline void timer_set(uint32_t t) { CLINT_MTIMECMPH = 0xFFFFFFFFu; CLINT_MTIMECMP = t; CLINT_MTIMECMPH = 0; }
static inline void timer_off(void)       { CLINT_MTIMECMPH = 0xFFFFFFFFu; CLINT_MTIMECMP = 0xFFFFFFFFu; }

// wait until *flag reaches value, at most cyc clocks; returns 1 on success
static inline int wait_eq(volatile uint32_t *flag, uint32_t value, uint32_t cyc)
{
  uint32_t t = now();
  while (*flag != value) if (now() - t > cyc) return 0;
  return 1;
}
