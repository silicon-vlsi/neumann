// model_test.h - riscv-arch-test target macros for the neumann SoC.
//
// The program is preloaded into IRAM (entry 0x8000_0080) and DRAM, boot pins = 01
// (direct boot). At the end RVMODEL_HALT writes the signature bounds and the done flag
// into the reserved DRAM words; the testbench then dumps the signature.
//   SIGBASE + 0x00  SIG_STATUS   0xC0DE0001 = test finished
//   SIGBASE + 0x10  begin_signature address
//   SIGBASE + 0x14  end_signature address
// SIGBASE = DRAM base: 0x8001_0000 (normal map) or 0x8020_0000 (big-memory map),
// passed by build.py as -DSIGBASE=...
#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

#ifndef SIGBASE
#define SIGBASE 0x80010000
#endif
#define ALIGNMENT 2

#define RVMODEL_HALT                                   \
  la   t0, begin_signature;                            \
  li   t1, SIGBASE;                                    \
  sw   t0, 0x10(t1);                                   \
  la   t0, end_signature;                              \
  sw   t0, 0x14(t1);                                   \
  li   t0, 0xC0DE0001;                                 \
  sw   t0, 0(t1);                                      \
  rvmodel_halt_loop: j rvmodel_halt_loop;

#define RVMODEL_BOOT

#define RVMODEL_DATA_BEGIN  .align 4; .global begin_signature; begin_signature:
#define RVMODEL_DATA_END    .align 4; .global end_signature; end_signature:

#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

#define RVMODEL_SET_MSW_INT
#define RVMODEL_CLEAR_MSW_INT
#define RVMODEL_CLEAR_MTIMER_INT
#define RVMODEL_CLEAR_MEXT_INT

#endif
