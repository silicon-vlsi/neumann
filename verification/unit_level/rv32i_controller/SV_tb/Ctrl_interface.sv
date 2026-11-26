`timescale 1ns/1ps
`include "rv32i_defines.vh"
interface Ctrl_interface
(
    input logic clk
);
logic rst_n;
logic fetch_enable_i;
logic illegal_insn_i;
logic ecall_insn_i;
logic mret_insn_i;
logic pipe_flush_i;
logic ebrk_insn_i;
logic csr_status_i;
logic instr_valid_i;
logic data_misaligned_i;
logic branch_in_id_i;
logic branch_taken_ex_i;
logic branch_set_i;
logic jump_set_i;
logic instr_multicyle_i;
logic irq_req_ctrl_i;
logic m_IE_i;
logic dbg_req_i;
logic dbg_stall_i;
logic dbg_jump_req_i;
logic id_ready_i;
logic [4:0] irq_id_ctrl_i;
logic [`DBG_SETS_W-1:0] dbg_settings_i;
logic ctrl_busy_o;
logic first_fetch_o;
logic is_decoding_o;
logic deassert_we_o;
logic instr_req_o;
logic pc_set_o;
logic irq_ack_o;
logic exc_ack_o;
logic exc_kill_o;
logic csr_save_if_o;
logic csr_save_id_o;
logic csr_restore_mret_id_o;
logic csr_save_cause_o;
logic dbg_ack_o;
logic dbg_trap_o;
logic halt_if_o;
logic halt_id_o;
logic perf_jump_o;
logic perf_tbranch_o;
logic [2:0] pc_mux_o;
logic [1:0] exc_pc_mux_o;
logic [4:0] irq_id_o;
logic [5:0] exc_cause_o;
logic [5:0] csr_cause_o;
logic [1:0] operand_a_fw_mux_sel_o;
logic [3:0] dbg_cs;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n, fetch_enable_i, illegal_insn_i, ecall_insn_i, mret_insn_i, pipe_flush_i;
output ebrk_insn_i, csr_status_i, instr_valid_i, data_misaligned_i, branch_in_id_i;
output branch_taken_ex_i, branch_set_i, jump_set_i, instr_multicyle_i, irq_req_ctrl_i, m_IE_i;
output dbg_req_i, dbg_stall_i, dbg_jump_req_i, id_ready_i, irq_id_ctrl_i, dbg_settings_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input rst_n, fetch_enable_i, illegal_insn_i, ecall_insn_i, mret_insn_i, pipe_flush_i;
input ebrk_insn_i, csr_status_i, instr_valid_i, data_misaligned_i, branch_in_id_i;
input branch_taken_ex_i, branch_set_i, jump_set_i, instr_multicyle_i, irq_req_ctrl_i, m_IE_i;
input dbg_req_i, dbg_stall_i, dbg_jump_req_i, id_ready_i, irq_id_ctrl_i, dbg_settings_i;
input ctrl_busy_o, first_fetch_o, is_decoding_o, deassert_we_o, instr_req_o, pc_set_o, irq_ack_o;
input exc_ack_o, exc_kill_o, csr_save_if_o, csr_save_id_o, csr_restore_mret_id_o;
input csr_save_cause_o, dbg_ack_o, dbg_trap_o, halt_if_o, halt_id_o, perf_jump_o, perf_tbranch_o;
input pc_mux_o, exc_pc_mux_o, irq_id_o, exc_cause_o, csr_cause_o, operand_a_fw_mux_sel_o, dbg_cs;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
