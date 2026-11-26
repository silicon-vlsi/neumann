// irq.c - interrupt stress test: CLINT (MTI, MSI) + PLIC (MEI) together.
//
// Interrupt sources used (all inside the SoC, no testbench help except the GPIO loopback
// gpio_i[7:0] = gpio_o[7:0]):
//   MSI  id 3   software writes CLINT msip
//   MTI  id 7   CLINT mtimecmp
//   MEI  id 11  PLIC; sources GPIO (3, rising edge on pin 0 via the loopback) and
//               SPI (6, TX-watermark interrupt: ip[0] = TX FIFO entries < txmark)
//
// Phases and results (RESULT[i], golden/irq.golden):
//  1 priority   all three pending while MIE = 0, then MIE = 1
//                 [0..2] order the core takes them: 11, 3, 7   [3] PLIC claim id: 3
//  2 PLIC       polling, MIE = 0: overlapping claims, complete, re-pend, tie, prio 0
//                 [4] pending 0x48  [5] claim 3  [6] claim 6  [7] claim 0
//                 [8] pending while both in progress 0  [9] claim after complete 6 (still
//                 requesting) 6  [10] pending after all done 0  [11] claim 0
//                 [12] tie, same priority: lowest id 3  [13] then 6
//                 [14] priority 0 source not claimable: 0
//  3 threshold  MIE = 1, GPIO priority 2: [15] taken with threshold 2? 0  [16] threshold 1: 1
//  4 timer      periodic 20 ticks, mtimecmp rewritten in the handler: [17] 20
//                 [18] mtimecmp moved far before it fired: extra ticks 0
//                 [19] then moved near: 1 tick
//  5 WFI        wfi loop until the timer handler sets a flag: [20] 1  [21] mtime >= target 1
//  6 stress     timer every 700 clocks + 50 x (MSI + GPIO edge) at the same time:
//                 [22] MSI 50  [23] GPIO MEI 50  [24] timer ticks > 0: 1
//                 [25] unexpected interrupt ids / claims: 0
#define TEST_NO_C_TRAP
#include "test.h"

static volatile uint32_t order[8], n_order;
static volatile uint32_t msi_cnt, mti_cnt, gpio_cnt, bad_cnt, last_claim;
static volatile uint32_t period;               // 0: one-shot (timer off after the tick)
static volatile uint32_t mti_limit;            // periodic mode stops after this many ticks

uint32_t c_trap(uint32_t mcause, uint32_t mepc)
{
  if ((int32_t)mcause >= 0) {                   // exception: not expected here
    SIG_STATUS = 0xBAD0F000u | (mcause & 0xFFFu);
    for (;;) ;
  }
  uint32_t id = mcause & 0x1F;
  if (n_order < 8) order[n_order] = id;
  n_order++;
  if (id == 3) {                                // MSI
    CLINT_MSIP = 0;
    msi_cnt++;
  } else if (id == 7) {                         // MTI
    mti_cnt++;
    if (period && mti_cnt < mti_limit) {
      uint32_t t = CLINT_MTIMECMP + period;      // rewrite: next tick one period later
      timer_set(t);
    } else timer_off();
  } else if (id == 11) {                        // MEI: claim everything pending
    uint32_t c;
    while ((c = PLIC_CLAIM0) != 0) {
      last_claim = c;
      if (c == PLIC_SRC_GPIO) { GPIO_RISE_IP = 0x01; gpio_cnt++; }
      else bad_cnt++;
      PLIC_CLAIM0 = c;                          // complete
    }
  } else bad_cnt++;
  return mepc;
}

// GPIO pin 0 rising edge through the loopback
static void gpio_edge(void)
{
  GPIO_OUTPUT_VAL = 0;
  delay(20);
  GPIO_OUTPUT_VAL = 1;
  delay(20);
}

int main(void)
{
  // GPIO pins 7:0 loop back (testbench); keep the boot-mode inputs 31:30 enabled
  GPIO_OUTPUT_VAL = 0;
  GPIO_OUTPUT_EN  = 0xFF;
  GPIO_INPUT_EN   = 0xC00000FF;
  GPIO_RISE_IE    = 0x01;
  delay(20);
  GPIO_RISE_IP    = 0xFFFFFFFF;
  PLIC_THRESH0    = 0;
  timer_off();

  // ---------------------------------------------------------------- 1 priority
  PLIC_PRIO(PLIC_SRC_GPIO) = 1;
  PLIC_ENABLE0 = 1u << PLIC_SRC_GPIO;
  CLINT_MSIP = 1;                               // MSI pending
  timer_set(0);                                 // MTI pending (mtime > 0)
  gpio_edge();                                  // MEI pending
  delay(20);
  n_order = 0;
  mie_on();
  wait_eq(&n_order, 3, 2000);
  mie_off();
  result(order[0]); result(order[1]); result(order[2]);
  result(last_claim);

  // ---------------------------------------------------------------- 2 PLIC claim / complete
  PLIC_PRIO(PLIC_SRC_GPIO) = 2;
  PLIC_PRIO(PLIC_SRC_SPI)  = 1;
  PLIC_ENABLE0 = (1u << PLIC_SRC_GPIO) | (1u << PLIC_SRC_SPI);
  gpio_edge();                                  // GPIO request (rise_ip stays set)
  SPIR(SPI_BASE, SPI_TXMARK) = 1;               // TX FIFO empty: 0 < 1 -> ip[0]
  SPIR(SPI_BASE, SPI_IE) = 1;                   // SPI request
  delay(20);
  result(PLIC_PENDING);                         // 0x48: bits 3 and 6
  result(PLIC_CLAIM0);                          // 3: higher priority first
  result(PLIC_CLAIM0);                          // 6: next one
  result(PLIC_CLAIM0);                          // 0: both in progress
  result(PLIC_PENDING);                         // 0: requests still high, but in progress
  PLIC_CLAIM0 = PLIC_SRC_SPI;                   // complete 6, SPI still requesting
  delay(10);
  result(PLIC_CLAIM0);                          // 6 again
  SPIR(SPI_BASE, SPI_IE) = 0;                   // remove the SPI request
  PLIC_CLAIM0 = PLIC_SRC_SPI;
  GPIO_RISE_IP = 0x01;                          // remove the GPIO request
  PLIC_CLAIM0 = PLIC_SRC_GPIO;
  delay(10);
  result(PLIC_PENDING);                         // 0
  result(PLIC_CLAIM0);                          // 0
  // tie: same priority -> lowest source id first
  PLIC_PRIO(PLIC_SRC_GPIO) = 1;
  gpio_edge();
  SPIR(SPI_BASE, SPI_IE) = 1;
  delay(20);
  uint32_t c1 = PLIC_CLAIM0, c2 = PLIC_CLAIM0;
  result(c1); result(c2);
  SPIR(SPI_BASE, SPI_IE) = 0;
  GPIO_RISE_IP = 0x01;
  PLIC_CLAIM0 = c1; PLIC_CLAIM0 = c2;
  // priority 0: never claimable
  PLIC_PRIO(PLIC_SRC_SPI) = 0;
  SPIR(SPI_BASE, SPI_IE) = 1;
  delay(20);
  result(PLIC_CLAIM0);                          // 0
  SPIR(SPI_BASE, SPI_IE) = 0;
  PLIC_ENABLE0 = 1u << PLIC_SRC_GPIO;
  delay(10);

  // ---------------------------------------------------------------- 3 threshold
  PLIC_PRIO(PLIC_SRC_GPIO) = 2;
  PLIC_THRESH0 = 2;                             // priority must be > threshold
  gpio_cnt = 0;
  mie_on();
  gpio_edge();
  delay(200);
  result(gpio_cnt);                             // 0: masked
  PLIC_THRESH0 = 1;
  wait_eq(&gpio_cnt, 1, 2000);
  result(gpio_cnt);                             // 1: taken now
  mie_off();
  PLIC_THRESH0 = 0;

  // ---------------------------------------------------------------- 4 timer, mtimecmp rewrites
  mti_cnt = 0; period = 2000; mti_limit = 20;
  mie_on();
  timer_set(now() + period);
  wait_eq(&mti_cnt, 20, 20 * 2000 + 20000);
  delay(5000);                                  // timer is off after tick 20: no more ticks
  result(mti_cnt);                              // 20
  period = 0; mti_cnt = 0;
  timer_set(now() + 1000);
  delay(200);
  timer_set(now() + 1000000);                   // moved far away before it fired
  delay(3000);
  result(mti_cnt);                              // 0
  timer_set(now() + 500);                       // moved near
  wait_eq(&mti_cnt, 1, 5000);
  delay(2000);
  result(mti_cnt);                              // 1
  mie_off();

  // ---------------------------------------------------------------- 5 WFI wake
  mti_cnt = 0;
  uint32_t target = now() + 3000;
  timer_set(target);
  mie_on();
  for (uint32_t i = 0; i < 100000 && mti_cnt == 0; i++)
    __asm__ volatile("wfi");
  mie_off();
  result(mti_cnt);                              // 1
  result((int32_t)(now() - target) >= 0);       // 1

  // ---------------------------------------------------------------- 6 stress
  msi_cnt = 0; gpio_cnt = 0; mti_cnt = 0; bad_cnt = 0;
  PLIC_PRIO(PLIC_SRC_GPIO) = 1;
  period = 700; mti_limit = 0xFFFFFFFFu;
  mie_on();
  timer_set(now() + period);
  for (uint32_t k = 1; k <= 50; k++) {
    CLINT_MSIP = 1;                             // MSI
    GPIO_OUTPUT_VAL = 0;                        // GPIO edge (MEI) without waiting in between
    delay(7 + (k % 5) * 13);                    // vary the timing against the timer
    GPIO_OUTPUT_VAL = 1;
    if (!wait_eq(&msi_cnt, k, 20000) || !wait_eq(&gpio_cnt, k, 20000)) break;
  }
  period = 0;
  timer_off();
  mie_off();
  result(msi_cnt);                              // 50
  result(gpio_cnt);                             // 50
  result(mti_cnt > 0);                          // 1
  result(bad_cnt);                              // 0
  return SIG_PASS;
}
