ENTRY(reset)
MEMORY { ROM (rx) : ORIGIN = 0x00001000, LENGTH = 4K }
SECTIONS { .text 0x00001000 : { *(.text) } > ROM }
