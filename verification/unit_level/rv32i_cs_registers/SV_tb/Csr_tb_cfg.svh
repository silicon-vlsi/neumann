// Testbench configuration for rv32i_cs_registers
// Number of built-in performance counters in the DUT (must match DUT parameter N_PERF_CNT).
// Override from the command line: vlog +define+CSR_N_PERF_CNT=11
`ifndef CSR_TB_CFG_SVH
`define CSR_TB_CFG_SVH
`ifndef CSR_N_PERF_CNT
`define CSR_N_PERF_CNT 2
`endif
`define CSR_PCCR_FIRST        12'h780
`define CSR_PCCR_LAST         (12'h780 + `CSR_N_PERF_CNT - 1)
`define CSR_PCCR_UNIMPL_FIRST (12'h780 + `CSR_N_PERF_CNT)
`define CSR_PCCR_UNIMPL_LAST  12'h79E
`endif
