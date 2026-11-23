# rom.S - neumann SoC boot ROM (0x0000_1000, 4 KB). boot_addr = 0x1000, reset at 0x1080.
#
# Boot mode = gpio_i[31:30] (boot pins), read once after reset:
#   1x : debug boot. Clear the mailbox (DRAM+4), poll it; the UART debug unit
#        writes the image with WMEM, then writes the entry address to the
#        mailbox. Jump there.
#   01 : direct boot. Image is already in IRAM/DRAM (simulation back-door
#        preload). Jump to IRAM + 0x80.
#   00 : SDC flash boot. A SPI flash on the SDC port (sdc_* pins, CS0) holds
#          flash 0x00 : header, 8 words (little-endian)
#                       [0] magic 0x4D55454E ("NEUM")   [1] iram_len (bytes)
#                       [2] dram_len (bytes)            [3] entry address
#                       [4] checksum = 32-bit sum of all image words
#                       [5..7] 0
#          flash 0x20 : IRAM image, iram_len bytes  -> 0x8000_0000
#          then       : DRAM image, dram_len bytes  -> 0x8001_0040 (.data)
#        Lengths: multiple of 4, iram_len <= 16 KB, dram_len <= 8 KB - 64.
#        Flash commands: 0xAB (release from power-down), 0x03 + 24-bit
#        address (read). SPI mode 0, SCK = clk / 4.
#        BOOT_STATUS (DRAM+0x0C): 0xB0070000 loading, 0xB00700AA ok (then
#        jump to entry), 0xB00700E1 bad magic, 0xB00700E2 bad length,
#        0xB00700E3 bad checksum. On an error the ROM falls back to debug boot.
    .option norvc
    .section .text
    .org 0x80
    .globl reset
reset:  j    boot          # 0x1080 reset
        j    rom_trap      # 0x1084 illegal
        j    rom_trap      # 0x1088 ecall
        j    rom_trap      # 0x108C load/store fault

    .equ GPIO_BASE,   0x10060000
    .equ SDC_BASE,    0x00013000
    .equ SPI_SCKDIV,  0x00
    .equ SPI_CSMODE,  0x18
    .equ SPI_TXDATA,  0x48
    .equ SPI_RXDATA,  0x4C
    .equ CSMODE_AUTO, 0
    .equ CSMODE_HOLD, 2
    .equ IRAM_BASE,   0x80000000
    .equ DRAM_DATA,   0x80010040
    .equ BOOT_STATUS, 0x8001000C
    .equ MAGIC,       0x4D55454E
    .equ IRAM_MAX,    16384
    .equ DRAM_MAX,    8128

boot:
    li   t0, 0x80000000
    csrw mtvec, t0
    li   sp, 0x80012000
    li   t1, GPIO_BASE
    li   t2, 0xC0000000
    sw   t2, 0x04(t1)      # input_en bits 31:30
    nop
    nop
    nop
    nop
    lw   t2, 0x00(t1)      # input_val (sync flops + APB): read twice
    lw   t2, 0x00(t1)
    bltz t2, dbg_boot      # bit 31 = 1 -> debug boot
    slli t3, t2, 1
    bgez t3, sdc_boot      # bit 30 = 0 -> SDC flash boot
direct_boot:
    li   t0, 0x80000080
    jr   t0

dbg_boot:
    li   t3, 0x80010004
    sw   zero, 0(t3)
wait_mb:
    lw   t0, 0(t3)
    beqz t0, wait_mb
    jr   t0

# ---------------------------------------------------------------- SDC flash boot
# s0 SDC base, s1 BOOT_STATUS, s2..s6 header, s7 running sum, s8 dst, s9 end
sdc_boot:
    li   s0, SDC_BASE
    li   s1, BOOT_STATUS
    li   t0, 0xB0070000
    sw   t0, 0(s1)
    li   t0, 1
    sw   t0, SPI_SCKDIV(s0)        # SCK = clk / (2 * (1 + 1))
    li   a0, 0xAB                  # release from deep power-down (own CS frame, AUTO mode)
    jal  spi_byte
    li   t0, 1000                  # >= 3 us (tRES1) at 100 MHz before the next command
1:  addi t0, t0, -1
    bnez t0, 1b
    li   t0, CSMODE_HOLD           # keep CS low for the whole read
    sw   t0, SPI_CSMODE(s0)
    li   a0, 0x03                  # READ, address 0x000000
    jal  spi_byte
    li   a0, 0
    jal  spi_byte
    li   a0, 0
    jal  spi_byte
    li   a0, 0
    jal  spi_byte
    jal  spi_word                  # header
    mv   s2, a0                    # magic
    jal  spi_word
    mv   s3, a0                    # iram_len
    jal  spi_word
    mv   s4, a0                    # dram_len
    jal  spi_word
    mv   s5, a0                    # entry
    jal  spi_word
    mv   s6, a0                    # checksum
    jal  spi_word
    jal  spi_word
    jal  spi_word
    li   t0, MAGIC
    li   a1, 0xB00700E1
    bne  s2, t0, boot_fail
    li   a1, 0xB00700E2
    or   t0, s3, s4
    andi t0, t0, 3
    bnez t0, boot_fail
    li   t0, IRAM_MAX
    bltu t0, s3, boot_fail
    li   t0, DRAM_MAX
    bltu t0, s4, boot_fail
    li   s7, 0
    li   s8, IRAM_BASE             # copy IRAM image
    add  s9, s8, s3
2:  beq  s8, s9, 3f
    jal  spi_word
    sw   a0, 0(s8)
    add  s7, s7, a0
    addi s8, s8, 4
    j    2b
3:  li   s8, DRAM_DATA             # copy DRAM image
    add  s9, s8, s4
4:  beq  s8, s9, 5f
    jal  spi_word
    sw   a0, 0(s8)
    add  s7, s7, a0
    addi s8, s8, 4
    j    4b
5:  sw   zero, SPI_CSMODE(s0)      # CSMODE = AUTO: release CS
    li   a1, 0xB00700E3
    bne  s7, s6, boot_fail
    li   t0, 0xB00700AA
    sw   t0, 0(s1)
    fence                          # (no caches: ordering only)
    jr   s5                        # entry

boot_fail:                         # a1 = status code
    sw   zero, SPI_CSMODE(s0)      # release CS
    sw   a1, 0(s1)
    j    dbg_boot

# spi_byte: send a0[7:0], return the received byte in a0. Uses t0.
spi_byte:
    sw   a0, SPI_TXDATA(s0)
1:  lw   a0, SPI_RXDATA(s0)
    bltz a0, 1b                    # bit 31 = RX FIFO empty
    andi a0, a0, 0xFF
    ret

# spi_word: clock in the next 4 flash bytes, return them as a little-endian
# word in a0. Uses t0, t2, t3.
spi_word:
    sw   zero, SPI_TXDATA(s0)      # 4 dummy bytes (TX FIFO is 8 deep)
    sw   zero, SPI_TXDATA(s0)
    sw   zero, SPI_TXDATA(s0)
    sw   zero, SPI_TXDATA(s0)
    li   a0, 0
    li   t2, 0
    li   t3, 32
1:  lw   t0, SPI_RXDATA(s0)
    bltz t0, 1b
    andi t0, t0, 0xFF
    sll  t0, t0, t2
    or   a0, a0, t0
    addi t2, t2, 8
    bne  t2, t3, 1b
    ret

rom_trap:
    j    rom_trap
