# start_rtos.S - IRAM image start for the FreeRTOS test.
# Same layout as sw/app/start.S (vector table at mtvec = 0x8000_0000, entry at +0x80),
# but every vector jumps to the FreeRTOS RISC-V trap handler (it dispatches on mcause):
#   interrupt n -> mtvec + 4n  (MTI = 7 -> +0x1C: the tick)
#   +0x84 illegal, +0x88 ecall (portYIELD), +0x8C load/store fault
    .option norvc
    .section .vectors, "ax"
    .globl _vectors
_vectors:
    .rept 32
    j    freertos_risc_v_trap_handler
    .endr
    j    _start                        # +0x80 entry (boot ROM jumps here)
    j    freertos_risc_v_trap_handler  # +0x84
    j    freertos_risc_v_trap_handler  # +0x88
    j    freertos_risc_v_trap_handler  # +0x8C

    .section .text
    .option rvc
    .globl _start
_start:
    la   sp, __stack_top               # main() stack; FreeRTOS uses its own ISR stack later
    la   t0, __bss_start
    la   t1, __bss_end
1:  bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:  call main
    li   t0, 0x80010000
    sw   a0, 0(t0)                     # main() only returns on error
3:  j    3b
