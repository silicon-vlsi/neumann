`timescale 1ns/1ps
`include "rv32i_defines.vh"
interface Id_interface
(
    input logic clk
);
logic rst_n;
logic test_en_i;
logic fetch_enable_i;
logic instr_valid_i;
logic [31:0] instr_rdata_i;
logic branch_decision_i;
logic illegal_c_insn_i;
logic is_compressed_i;
logic [31:0] pc_id_i;
logic ex_ready_i;
logic data_misaligned_i;
logic [31:0] misaligned_addr_i;
logic irq_i;
logic [4:0] irq_id_i;
logic m_irq_enable_i;
logic lsu_load_err_i;
logic lsu_store_err_i;
logic [`DBG_SETS_W-1:0] dbg_settings_i;
logic dbg_req_i;
logic dbg_stall_i;
logic dbg_reg_rreq_i;
logic [4:0] dbg_reg_raddr_i;
logic dbg_reg_wreq_i;
logic [4:0] dbg_reg_waddr_i;
logic [31:0] dbg_reg_wdata_i;
logic dbg_jump_req_i;
logic [31:0] regfile_wdata_lsu_i;
logic [31:0] regfile_wdata_ex_i;
logic [31:0] csr_rdata_i;
logic ctrl_busy_o;
logic core_ctrl_firstfetch_o;
logic is_decoding_o;
logic instr_req_o;
logic branch_in_ex_o;
logic clear_instr_valid_o;
logic pc_set_o;
logic [2:0] pc_mux_o;
logic [1:0] exc_pc_mux_o;
logic halt_if_o;
logic id_ready_o;
logic id_valid_o;
logic [`ALU_OP_WIDTH-1:0] alu_operator_ex_o;
logic [31:0] alu_operand_a_ex_o;
logic [31:0] alu_operand_b_ex_o;
logic csr_access_ex_o;
logic [1:0] csr_op_ex_o;
logic [5:0] csr_cause_o;
logic csr_save_if_o;
logic csr_save_id_o;
logic csr_restore_mret_id_o;
logic csr_save_cause_o;
logic data_req_ex_o;
logic data_we_ex_o;
logic [1:0] data_type_ex_o;
logic data_sign_ext_ex_o;
logic [1:0] data_reg_offset_ex_o;
logic data_load_event_ex_o;
logic [31:0] data_wdata_ex_o;
logic irq_ack_o;
logic [4:0] irq_id_o;
logic [5:0] exc_cause_o;
logic dbg_ack_o;
logic dbg_trap_o;
logic [31:0] dbg_reg_rdata_o;
logic perf_jump_o;
logic perf_branch_o;
logic perf_tbranch_o;
logic dbg_wb_cs;
logic dbg_halt_id;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n, test_en_i, fetch_enable_i, instr_valid_i, instr_rdata_i, branch_decision_i;
output illegal_c_insn_i, is_compressed_i, pc_id_i, ex_ready_i, data_misaligned_i;
output misaligned_addr_i, irq_i, irq_id_i, m_irq_enable_i, lsu_load_err_i, lsu_store_err_i;
output dbg_settings_i, dbg_req_i, dbg_stall_i, dbg_reg_rreq_i, dbg_reg_raddr_i, dbg_reg_wreq_i;
output dbg_reg_waddr_i, dbg_reg_wdata_i, dbg_jump_req_i, regfile_wdata_lsu_i, regfile_wdata_ex_i;
output csr_rdata_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input rst_n, test_en_i, fetch_enable_i, instr_valid_i, instr_rdata_i, branch_decision_i;
input illegal_c_insn_i, is_compressed_i, pc_id_i, ex_ready_i, data_misaligned_i;
input misaligned_addr_i, irq_i, irq_id_i, m_irq_enable_i, lsu_load_err_i, lsu_store_err_i;
input dbg_settings_i, dbg_req_i, dbg_stall_i, dbg_reg_rreq_i, dbg_reg_raddr_i, dbg_reg_wreq_i;
input dbg_reg_waddr_i, dbg_reg_wdata_i, dbg_jump_req_i, regfile_wdata_lsu_i, regfile_wdata_ex_i;
input csr_rdata_i;
input ctrl_busy_o, core_ctrl_firstfetch_o, is_decoding_o, instr_req_o, branch_in_ex_o;
input clear_instr_valid_o, pc_set_o, pc_mux_o, exc_pc_mux_o, halt_if_o, id_ready_o, id_valid_o;
input alu_operator_ex_o, alu_operand_a_ex_o, alu_operand_b_ex_o, csr_access_ex_o, csr_op_ex_o;
input csr_cause_o, csr_save_if_o, csr_save_id_o, csr_restore_mret_id_o, csr_save_cause_o;
input data_req_ex_o, data_we_ex_o, data_type_ex_o, data_sign_ext_ex_o, data_reg_offset_ex_o;
input data_load_event_ex_o, data_wdata_ex_o, irq_ack_o, irq_id_o, exc_cause_o, dbg_ack_o;
input dbg_trap_o, dbg_reg_rdata_o, perf_jump_o, perf_branch_o, perf_tbranch_o, dbg_wb_cs;
input dbg_halt_id;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
