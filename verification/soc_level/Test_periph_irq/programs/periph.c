// periph.c - directed tests of the application UART, the user SPI master and the GPIO.
//
// Testbench connections: uart_rx_i = uart_tx_o (loopback), SPI CS0 -> spi_mem.sv
// (256-byte memory: 0x02 addr data... = write, 0x03 addr -> data... = read, SPI mode 0),
// gpio_i[7:0] = gpio_o[7:0] (loopback).
//
// Results (RESULT[i], golden/periph.golden):
//  UART  [0] LCR 0x03  [1] DLL read back 27  [2] LSR after init 0x60 (THR empty, TX empty)
//        [3] polled loopback: bytes received 8  [4] mismatches 0
//        [5] RX FIFO: 16 bytes sent with nobody reading, received 16  [6] mismatches 0
//        [7] interrupt mode: bytes received in the ISR 8  [8] mismatches 0
//        [9] PLIC claim id 10  [10] IIR in the ISR 0xC4 (FIFO on, received data available)
//  SPI   [11] write 16 bytes, read back at sckdiv 1: mismatches 0
//        [12] read back at sckdiv 0: mismatches 0  [13] at sckdiv 7: mismatches 0
//        [14] ip[0] with txmark 1 (TX empty): 1  [15] with txmark 0: 0
//        [16] ip[1] with 4 bytes in RX and rxmark 2: 1  [17] after reading 2: 0
//        [18] RX-watermark interrupt: PLIC claim id 6  [19] byte read in the ISR = memory[0x10]
//  GPIO  [20] input_val 0xA5 via loopback
//        [21] rise_ip 0x02  [22] after writing 0: 0x02  [23] after writing 1 to bit 0: 0x02
//        [24] after writing 1 to bit 1: 0x00
//        [25] fall_ip 0x04  [26] after clear: 0x00
//        [27] high_ip bit 3 while high: 1  [28] cleared while still high: 1 (level)
//        [29] cleared after going low: 0
//        [30] low_ip bit 4 while low: 1  [31] cleared while still low: 1  [32] after high: 0
//        [33] rise interrupt through the PLIC: claim id 3  [34] rise_ip seen in the ISR 0x20
//        [35] high-level interrupt taken once (ISR turns high_ie off): 1
//        [36] unexpected interrupts: 0
#define TEST_NO_C_TRAP
#include "test.h"

#define SPI(o) SPIR(SPI_BASE, (o))

static volatile uint8_t  ubuf[32];
static volatile uint32_t un, uiir, uclaim;
static volatile uint32_t sclaim, sbyte, sdone;
static volatile uint32_t gclaim, grise, gcnt, ghigh, bad_cnt;
static volatile uint32_t mode;                  // which ISR behaviour: 1 UART, 2 SPI, 3 GPIO

uint32_t c_trap(uint32_t mcause, uint32_t mepc)
{
  if ((int32_t)mcause >= 0 || (mcause & 0x1F) != 11) {
    SIG_STATUS = 0xBAD0F000u | (mcause & 0xFFFu);
    for (;;) ;
  }
  uint32_t c;
  while ((c = PLIC_CLAIM0) != 0) {
    if (c == PLIC_SRC_UART && mode == 1) {
      uclaim = c;
      uint32_t iir = UART_IIR;
      if (uiir == 0) uiir = iir;
      while (UART_LSR & 0x01) { uint8_t d = UART_RBR; if (un < 32) ubuf[un] = d; un++; }
    } else if (c == PLIC_SRC_SPI && mode == 2) {
      sclaim = c;
      sbyte = SPI(SPI_RXDATA) & 0xFF;            // drains the RX FIFO -> request goes away
      SPI(SPI_IE) = 0;
      sdone = 1;
    } else if (c == PLIC_SRC_GPIO && mode == 3) {
      gclaim = c;
      uint32_t r = GPIO_RISE_IP & 0xFF;
      if (r) { grise = r; GPIO_RISE_IP = r; }
      if (GPIO_HIGH_IP & GPIO_HIGH_IE & 0x40) { GPIO_HIGH_IE = 0; ghigh++; }
      gcnt++;
    } else bad_cnt++;
    PLIC_CLAIM0 = c;
  }
  return mepc;
}

// ---------------------------------------------------------------- UART
static const char msg[] = "neumann!SoC 2026 loopback test..";   // 32 bytes

static void uart_put(uint8_t c) { while (!(UART_LSR & 0x20)) { } UART_THR = c; }

// receive n bytes (polled) into ubuf; one character = 10 bits x 32 x 27 = 8640 clocks
static uint32_t uart_get(uint32_t n)
{
  uint32_t got = 0, t = now();
  while (got < n && now() - t < (n + 4) * 9000) {
    if (UART_LSR & 0x01) { ubuf[got++] = UART_RBR; t = now(); }
  }
  return got;
}

static uint32_t mismatches(const char *exp, uint32_t n)
{
  uint32_t e = 0;
  for (uint32_t i = 0; i < n; i++) if (ubuf[i] != (uint8_t)exp[i]) e++;
  return e;
}

static void test_uart(void)
{
  UART_LCR = 0x80; UART_DLL = 27; UART_DLM = 0;  // 115200 at 100 MHz
  UART_LCR = 0x03; UART_FCR = 0x07;              // 8N1, FIFOs on and reset, RX trigger 1
  result(UART_LCR);                              // 0x03
  UART_LCR = 0x83; result(UART_DLL); UART_LCR = 0x03;   // 27
  delay(50);
  result(UART_LSR);                              // 0x60

  for (int i = 0; i < 8; i++) uart_put(msg[i]);  // polled loopback
  result(uart_get(8));                           // 8
  result(mismatches(msg, 8));                    // 0

  for (int i = 0; i < 16; i++) uart_put(msg[16 + i]);   // fill the 16-byte RX FIFO
  while (!(UART_LSR & 0x40)) ;                   // transmitter empty: last byte on the line
  delay(9000);                                   // ... and received
  result(uart_get(16));                          // 16
  result(mismatches(msg + 16, 16));              // 0

  un = 0; uiir = 0; mode = 1;                    // interrupt mode
  PLIC_PRIO(PLIC_SRC_UART) = 1;
  PLIC_ENABLE0 = 1u << PLIC_SRC_UART;
  UART_IER = 0x01;                               // received data available
  mie_on();
  for (int i = 0; i < 8; i++) uart_put(msg[8 + i]);
  wait_eq(&un, 8, 12 * 9000);
  mie_off();
  UART_IER = 0;
  result(un);                                    // 8
  result(mismatches(msg + 8, 8));                // 0
  result(uclaim);                                // 10
  result(uiir);                                  // 0xC4
}

// ---------------------------------------------------------------- SPI
static uint8_t spi_xfer(uint8_t b)
{
  SPI(SPI_TXDATA) = b;
  int32_t r;
  while ((r = (int32_t)SPI(SPI_RXDATA)) < 0) ;
  return (uint8_t)r;
}

static void spi_begin(void) { SPI(SPI_CSMODE) = 2; }       // HOLD: CS stays low
static void spi_end(void)   { SPI(SPI_CSMODE) = 0; }       // AUTO: CS released

static uint8_t pattern(int i) { return (uint8_t)(i * 37 + 11); }

static uint32_t spi_check(void)
{
  uint32_t e = 0;
  spi_begin();
  spi_xfer(0x03); spi_xfer(0x10);
  for (int i = 0; i < 16; i++) if (spi_xfer(0) != pattern(i)) e++;
  spi_end();
  return e;
}

static void test_spi(void)
{
  SPI(SPI_CSID) = 0;
  SPI(SPI_SCKMODE) = 0;                          // mode 0
  SPI(SPI_SCKDIV) = 1;
  spi_begin();
  spi_xfer(0x02); spi_xfer(0x10);
  for (int i = 0; i < 16; i++) spi_xfer(pattern(i));
  spi_end();
  result(spi_check());                           // 0
  SPI(SPI_SCKDIV) = 0; result(spi_check());      // 0
  SPI(SPI_SCKDIV) = 7; result(spi_check());      // 0
  SPI(SPI_SCKDIV) = 1;

  SPI(SPI_TXMARK) = 1; delay(10); result(SPI(SPI_IP) & 1);  // 1
  SPI(SPI_TXMARK) = 0; delay(10); result(SPI(SPI_IP) & 1);  // 0
  SPI(SPI_RXMARK) = 2;
  spi_begin();
  spi_xfer(0x03); spi_xfer(0x10);
  for (int i = 0; i < 4; i++) SPI(SPI_TXDATA) = 0;          // 4 bytes in, not read
  delay(500);
  result((SPI(SPI_IP) >> 1) & 1);                // 1: 4 > 2
  (void)SPI(SPI_RXDATA); (void)SPI(SPI_RXDATA);
  delay(10);
  result((SPI(SPI_IP) >> 1) & 1);                // 0: 2 > 2 is false
  (void)SPI(SPI_RXDATA); (void)SPI(SPI_RXDATA);
  spi_end();

  mode = 2; sdone = 0;                           // RX-watermark interrupt
  SPI(SPI_RXMARK) = 0;                           // ip[1] when RX has > 0 entries
  PLIC_PRIO(PLIC_SRC_SPI) = 1;
  PLIC_ENABLE0 = 1u << PLIC_SRC_SPI;
  spi_begin();
  spi_xfer(0x03); spi_xfer(0x10);
  SPI(SPI_IE) = 2;
  mie_on();
  SPI(SPI_TXDATA) = 0;                           // one byte: memory[0x10]
  wait_eq(&sdone, 1, 2000);
  mie_off();
  spi_end();
  result(sclaim);                                // 6
  result(sbyte == pattern(0));                   // 1
}

// ---------------------------------------------------------------- GPIO
static void out(uint32_t v) { GPIO_OUTPUT_VAL = v; delay(20); }

static void test_gpio(void)
{
  GPIO_OUTPUT_EN = 0xFF;
  GPIO_INPUT_EN  = 0xC00000FF;
  out(0xA5);
  result(GPIO_INPUT_VAL & 0xFF);                 // 0xA5

  out(0x00); GPIO_RISE_IP = 0xFF;
  out(0x02);
  result(GPIO_RISE_IP & 0xFF);                   // 0x02
  GPIO_RISE_IP = 0x00; result(GPIO_RISE_IP & 0xFF);   // 0x02: writing 0 does nothing
  GPIO_RISE_IP = 0x01; result(GPIO_RISE_IP & 0xFF);   // 0x02: other bit
  GPIO_RISE_IP = 0x02; result(GPIO_RISE_IP & 0xFF);   // 0x00

  out(0x04); GPIO_FALL_IP = 0xFF;
  out(0x00);
  result(GPIO_FALL_IP & 0xFF);                   // 0x04
  GPIO_FALL_IP = 0x04; result(GPIO_FALL_IP & 0xFF);   // 0x00

  out(0x08);
  result((GPIO_HIGH_IP >> 3) & 1);               // 1
  GPIO_HIGH_IP = 0x08; delay(5); result((GPIO_HIGH_IP >> 3) & 1);   // 1: still high
  out(0x00); GPIO_HIGH_IP = 0x08; delay(5); result((GPIO_HIGH_IP >> 3) & 1);   // 0

  result((GPIO_LOW_IP >> 4) & 1);                // 1
  GPIO_LOW_IP = 0x10; delay(5); result((GPIO_LOW_IP >> 4) & 1);     // 1: still low
  out(0x10); GPIO_LOW_IP = 0x10; delay(5); result((GPIO_LOW_IP >> 4) & 1);     // 0
  out(0x00);

  // interrupts through the PLIC
  mode = 3; gcnt = 0; ghigh = 0; grise = 0;
  GPIO_RISE_IP = 0xFFFFFFFF; GPIO_HIGH_IP = 0xFFFFFFFF;
  GPIO_RISE_IE = 0x20;
  PLIC_PRIO(PLIC_SRC_GPIO) = 1;
  PLIC_ENABLE0 = 1u << PLIC_SRC_GPIO;
  mie_on();
  out(0x20);                                     // rising edge on pin 5
  wait_eq(&gcnt, 1, 2000);
  result(gclaim);                                // 3
  result(grise);                                 // 0x20
  GPIO_RISE_IE = 0;
  GPIO_HIGH_IE = 0x40;
  out(0x60);                                     // pin 6 high: level interrupt
  wait_eq(&ghigh, 1, 2000);
  delay(500);                                    // ISR turned high_ie off: no storm
  result(ghigh);                                 // 1
  mie_off();
  out(0x00);
}

int main(void)
{
  PLIC_THRESH0 = 0;
  timer_off();
  test_uart();
  test_spi();
  test_gpio();
  result(bad_cnt);                               // 0
  return SIG_PASS;
}
