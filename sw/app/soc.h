// soc.h - neumann SoC memory map (see doc/MEMORY_MAP.md)
#pragma once
#include <stdint.h>
#define REG32(a) (*(volatile uint32_t *)(a))
#define REG8(a)  (*(volatile uint8_t  *)(a))

#define BOOTROM_BASE 0x00001000u
#define IRAM_BASE    0x80000000u
#define IRAM_SIZE    (16u * 1024u)
#define DRAM_BASE    0x80010000u
#define DRAM_SIZE    ( 8u * 1024u)

// CLINT
#define CLINT_BASE     0x02000000u
#define CLINT_MSIP     REG32(CLINT_BASE + 0x0000)
#define CLINT_MTIMECMP REG32(CLINT_BASE + 0x4000)
#define CLINT_MTIMECMPH REG32(CLINT_BASE + 0x4004)
#define CLINT_MTIME    REG32(CLINT_BASE + 0xBFF8)
#define CLINT_MTIMEH   REG32(CLINT_BASE + 0xBFFC)

// PLIC (context 0 = machine mode)
#define PLIC_BASE      0x0C000000u
#define PLIC_PRIO(s)   REG32(PLIC_BASE + 4u * (s))
#define PLIC_PENDING   REG32(PLIC_BASE + 0x001000)
#define PLIC_ENABLE0   REG32(PLIC_BASE + 0x002000)
#define PLIC_THRESH0   REG32(PLIC_BASE + 0x200000)
#define PLIC_CLAIM0    REG32(PLIC_BASE + 0x200004)
#define PLIC_SRC_GPIO  3
#define PLIC_SRC_UART  10

// UART 16550 (byte registers)
#define UART_BASE 0x10000000u
#define UART_RBR  REG8(UART_BASE + 0)
#define UART_THR  REG8(UART_BASE + 0)
#define UART_DLL  REG8(UART_BASE + 0)
#define UART_IER  REG8(UART_BASE + 1)
#define UART_DLM  REG8(UART_BASE + 1)
#define UART_LCR  REG8(UART_BASE + 3)
#define UART_LSR  REG8(UART_BASE + 5)

// GPIO (word registers)
// SPI and SDC (2nd SPI master, boot flash on CS0): same Wally spi_apb register map
#define SPI_BASE       0x10040000u
#define SDC_BASE       0x00013000u
#define SPIR(b, o)     REG32((b) + (o))
#define SPI_SCKDIV     0x00
#define SPI_CSID       0x10
#define SPI_CSDEF      0x14
#define SPI_CSMODE     0x18
#define SPI_FMT        0x40
#define SPI_TXDATA     0x48   // bit 31 = TX FIFO full
#define SPI_RXDATA     0x4C   // bit 31 = RX FIFO empty, [7:0] data
#define SPI_RXMARK     0x54
#define SPI_IE         0x70   // bit 1 = RX watermark interrupt
#define SPI_IP         0x74
#define PLIC_SRC_SPI   6
#define PLIC_SRC_SDC   9

#define GPIO_BASE      0x10060000u
#define GPIO_INPUT_VAL REG32(GPIO_BASE + 0x00)
#define GPIO_INPUT_EN  REG32(GPIO_BASE + 0x04)
#define GPIO_OUTPUT_EN REG32(GPIO_BASE + 0x08)
#define GPIO_OUTPUT_VAL REG32(GPIO_BASE + 0x0C)
#define GPIO_RISE_IE   REG32(GPIO_BASE + 0x18)
#define GPIO_RISE_IP   REG32(GPIO_BASE + 0x1C)

// test signature in DRAM (read by the testbench)
#define SIG_STATUS  REG32(DRAM_BASE + 0x0)   // 0xC0DE0001 pass, 0xBAD00000 | test number on fail
#define SIG_MAILBOX REG32(DRAM_BASE + 0x4)   // boot ROM debug-load mailbox (entry address)
#define SIG_STEP    REG32(DRAM_BASE + 0x8)   // last test step reached
#define BOOT_STATUS REG32(DRAM_BASE + 0xC)   // boot ROM: 0xB00700AA flash boot ok, 0xB00700Ex error
#define SIG_PASS    0xC0DE0001u
