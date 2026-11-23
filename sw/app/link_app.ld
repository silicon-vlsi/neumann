/* neumann SoC application: code in IRAM, data/bss/stack in DRAM.
   DRAM 0x8001_0000..0x8001_003F is reserved for the test signature / boot mailbox. */
MEMORY {
  IRAM (rx)  : ORIGIN = 0x80000000, LENGTH = 16K
  DRAM (rw)  : ORIGIN = 0x80010040, LENGTH = 8K - 64
}
ENTRY(_start)
SECTIONS {
  .vectors 0x80000000 : { KEEP(*(.vectors)) } > IRAM
  .text : { *(.text .text.*) *(.rodata .rodata.* .srodata .srodata.*) } > IRAM
  .data : { *(.data .data.* .sdata .sdata.*) } > DRAM
  .bss  : { __bss_start = .; *(.bss .bss.* .sbss .sbss.* COMMON); . = ALIGN(4); __bss_end = .; } > DRAM
  __stack_top = 0x80012000;
}
