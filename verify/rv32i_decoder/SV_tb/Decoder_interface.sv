`timescale 1ns/1ps
`include "rv32i_defines.vh"
interface Decoder_interface
(
    input logic clk
);
logic valid;
logic        deassert_we_i;
logic        data_misaligned_i;
logic        branch_mux_i;
logic        jump_mux_i;
logic [31:0] instr_rdata_i;
logic        illegal_c_insn_i;
logic                     illegal_insn_o;
logic                     ebrk_insn_o;
logic                     mret_insn_o;
logic                     ecall_insn_o;
logic                     pipe_flush_o;
logic [`ALU_OP_WIDTH-1:0] alu_operator_o;
logic [2:0]               alu_op_a_mux_sel_o;
logic [2:0]               alu_op_b_mux_sel_o;
logic                     imm_a_mux_sel_o;
logic [3:0]               imm_b_mux_sel_o;
logic                     regfile_we_o;
logic                     csr_access_o;
logic [1:0]               csr_op_o;
logic                     csr_status_o;
logic                     data_req_o;
logic                     data_we_o;
logic [1:0]               data_type_o;
logic                     data_sign_extension_o;
logic [1:0]               data_reg_offset_o;
logic                     data_load_event_o;
logic                     jump_in_id_o;
logic                     branch_in_id_o;

clocking drv_cb @(posedge clk);
default output #1;
output valid;
output deassert_we_i, data_misaligned_i, branch_mux_i, jump_mux_i, instr_rdata_i, illegal_c_insn_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input valid;
input deassert_we_i, data_misaligned_i, branch_mux_i, jump_mux_i, instr_rdata_i, illegal_c_insn_i;
input illegal_insn_o, ebrk_insn_o, mret_insn_o, ecall_insn_o, pipe_flush_o;
input alu_operator_o, alu_op_a_mux_sel_o, alu_op_b_mux_sel_o, imm_a_mux_sel_o, imm_b_mux_sel_o;
input regfile_we_o, csr_access_o, csr_op_o, csr_status_o;
input data_req_o, data_we_o, data_type_o, data_sign_extension_o, data_reg_offset_o, data_load_event_o;
input jump_in_id_o, branch_in_id_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
