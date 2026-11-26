// gpio32.c - all 32 GPIO pins and the output-invert register (out_xor).
//
// Testbench: gpio_i = gpio_o on every pin whose gpio_oe_o = 1; a pin that is not driven
// reads the board default (0, except boot pin 30 = 1).
//
// Results (RESULT[i], golden/gpio32.golden):
//  [0] walking 1 over 32 pins: patterns read back correctly on input_val: 32
//  [1] walking 0 over 32 pins: 32
//  [2] output_val reads back what was written, all 64 patterns: 64
//  [3] input_val with 0xA5A5A5A5: 0xA5A5A5A5     [4] with 0x5A5A5A5A: 0x5A5A5A5A
//  [5] out_xor 0xFFFF0000, output 0: pins = 0xFFFF0000
//  [6] out_xor 0xFFFF0000, output 0x0F0F0F0F: pins = 0xF0F00F0F
//  [7] out_xor read back: 0xFFFF0000
//  [8] input_en 0x0000FFFF, all pins high: input_val = 0x0000FFFF
//  [9] output_en 0x00FF00FF, output all 1: input_val = 0x40FF00FF (undriven pins: board value)
//  [10] rise_ip after all 32 pins 0 -> 1: 0xFFFFFFFF   [11] fall_ip after 1 -> 0: 0xFFFFFFFF
//  [12] high_ip with all pins high: 0xFFFFFFFF          [13] low_ip with all pins low: 0xFFFFFFFF
//  [14] rise_ip after writing 1s to clear, pins steady: 0x00000000
//  [15] edge interrupt on pins 31 and 16 through the PLIC: claim id 3
//  [16] rise_ip & rise_ie seen in the ISR: 0x80010000
//  [17] unexpected traps: 0
#define TEST_NO_C_TRAP
#include "test.h"

#define GPIO_OUT_XOR REG32(GPIO_BASE + 0x40)

static volatile uint32_t claim, seen, done, bad;

uint32_t c_trap(uint32_t mcause, uint32_t mepc)
{
  if ((int32_t)mcause >= 0 || (mcause & 0x1F) != 11) {
    SIG_STATUS = 0xBAD0F000u | (mcause & 0xFFFu);
    for (;;) ;
  }
  uint32_t c;
  while ((c = PLIC_CLAIM0) != 0) {
    if (c == PLIC_SRC_GPIO) {
      claim = c;
      seen = GPIO_RISE_IP & GPIO_RISE_IE;
      GPIO_RISE_IP = seen;
      done = 1;
    } else bad++;
    PLIC_CLAIM0 = c;
  }
  return mepc;
}

static void out(uint32_t v) { GPIO_OUTPUT_VAL = v; delay(20); }

int main(void)
{
  timer_off();
  GPIO_OUT_XOR   = 0;
  GPIO_INPUT_EN  = 0xFFFFFFFF;
  GPIO_OUTPUT_EN = 0xFFFFFFFF;

  uint32_t ok1 = 0, ok0 = 0, okr = 0;
  for (int i = 0; i < 32; i++) {
    uint32_t p = 1u << i;
    out(p);  if (GPIO_INPUT_VAL == p)  ok1++;  if (GPIO_OUTPUT_VAL == p)  okr++;
    out(~p); if (GPIO_INPUT_VAL == ~p) ok0++;  if (GPIO_OUTPUT_VAL == ~p) okr++;
  }
  result(ok1); result(ok0); result(okr);
  out(0xA5A5A5A5u); result(GPIO_INPUT_VAL);
  out(0x5A5A5A5Au); result(GPIO_INPUT_VAL);

  GPIO_OUT_XOR = 0xFFFF0000u;
  out(0);            result(GPIO_INPUT_VAL);
  out(0x0F0F0F0Fu);  result(GPIO_INPUT_VAL);
  result(GPIO_OUT_XOR);
  GPIO_OUT_XOR = 0;

  GPIO_INPUT_EN = 0x0000FFFFu;
  out(0xFFFFFFFFu);  result(GPIO_INPUT_VAL);
  GPIO_INPUT_EN = 0xFFFFFFFFu;

  GPIO_OUTPUT_EN = 0x00FF00FFu;
  out(0xFFFFFFFFu);  result(GPIO_INPUT_VAL);
  GPIO_OUTPUT_EN = 0xFFFFFFFFu;

  out(0);
  GPIO_RISE_IP = 0xFFFFFFFF; GPIO_FALL_IP = 0xFFFFFFFF;
  out(0xFFFFFFFFu);  result(GPIO_RISE_IP);
  out(0);            result(GPIO_FALL_IP);
  out(0xFFFFFFFFu);  GPIO_HIGH_IP = 0xFFFFFFFF; delay(5); result(GPIO_HIGH_IP);
  out(0);            GPIO_LOW_IP  = 0xFFFFFFFF; delay(5); result(GPIO_LOW_IP);
  GPIO_RISE_IP = 0xFFFFFFFF; delay(5); result(GPIO_RISE_IP);

  // rising edges on pins 31 and 16 -> PLIC source 3 -> MEI
  GPIO_RISE_IP = 0xFFFFFFFF;
  GPIO_RISE_IE = 0x80010000u;
  PLIC_PRIO(PLIC_SRC_GPIO) = 1;
  PLIC_ENABLE0 = 1u << PLIC_SRC_GPIO;
  PLIC_THRESH0 = 0;
  mie_on();
  out(0x80010000u);
  wait_eq(&done, 1, 2000);
  mie_off();
  GPIO_RISE_IE = 0;
  result(claim);
  result(seen);
  result(bad);
  out(0);
  return SIG_PASS;
}
