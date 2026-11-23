# start.S - IRAM image start: vector table (mtvec = 0x8000_0000), entry at +0x80, trap entry.
    .option norvc
    .section .vectors, "ax"
    .globl _vectors
_vectors:
    .rept 32
    j    trap_entry        # interrupt id n -> mtvec + 4n
    .endr
    j    _start            # +0x80 entry (boot ROM jumps here)
    j    trap_entry        # +0x84 illegal instruction
    j    trap_entry        # +0x88 ecall
    j    trap_entry        # +0x8C load/store access fault

    .section .text
    .option rvc
    .globl _start
_start:
    la   sp, __stack_top
    la   t0, __bss_start
    la   t1, __bss_end
1:  bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:  call main
    li   t0, 0x80010000
    sw   a0, 0(t0)         # main() return value -> SIG_STATUS
3:  j    3b

# common trap entry: save caller-saved regs, a0 = mcause, a1 = mepc,
# c_trap returns new mepc.
    .globl trap_entry
    .balign 4
trap_entry:
    addi sp, sp, -64
    sw ra,  0(sp); sw t0,  4(sp); sw t1,  8(sp); sw t2, 12(sp)
    sw a0, 16(sp); sw a1, 20(sp); sw a2, 24(sp); sw a3, 28(sp)
    sw a4, 32(sp); sw a5, 36(sp); sw a6, 40(sp); sw a7, 44(sp)
    sw t3, 48(sp); sw t4, 52(sp); sw t5, 56(sp); sw t6, 60(sp)
    csrr a0, mcause
    csrr a1, mepc
    call c_trap
    csrw mepc, a0
    lw ra,  0(sp); lw t0,  4(sp); lw t1,  8(sp); lw t2, 12(sp)
    lw a0, 16(sp); lw a1, 20(sp); lw a2, 24(sp); lw a3, 28(sp)
    lw a4, 32(sp); lw a5, 36(sp); lw a6, 40(sp); lw a7, 44(sp)
    lw t3, 48(sp); lw t4, 52(sp); lw t5, 56(sp); lw t6, 60(sp)
    addi sp, sp, 64
    mret
