`timescale 1ns/1ps
`include "rv32i_defines.vh"
interface If_interface
(
    input logic clk
);
logic rst_n;
logic [31:0] boot_addr_i;
logic req_i;
logic instr_gnt_i;
logic instr_rvalid_i;
logic [31:0] instr_rdata_i;
logic clear_instr_valid_i;
logic pc_set_i;
logic [31:0] exception_pc_reg_i;
logic [2:0] pc_mux_i;
logic [1:0] exc_pc_mux_i;
logic [4:0] exc_vec_pc_mux_i;
logic [31:0] jump_target_ex_i;
logic [31:0] dbg_jump_addr_i;
logic halt_if_i;
logic id_ready_i;
logic instr_req_o;
logic [31:0] instr_addr_o;
logic instr_valid_id_o;
logic [31:0] instr_rdata_id_o;
logic is_compressed_id_o;
logic illegal_c_insn_id_o;
logic [31:0] pc_if_o;
logic [31:0] pc_id_o;
logic if_valid_o;
logic if_busy_o;
logic perf_imiss_o;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n, boot_addr_i, req_i, instr_gnt_i, instr_rvalid_i, instr_rdata_i;
output clear_instr_valid_i, pc_set_i, exception_pc_reg_i, pc_mux_i, exc_pc_mux_i;
output exc_vec_pc_mux_i, jump_target_ex_i, dbg_jump_addr_i, halt_if_i, id_ready_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input rst_n, boot_addr_i, req_i, instr_gnt_i, instr_rvalid_i, instr_rdata_i, clear_instr_valid_i;
input pc_set_i, exception_pc_reg_i, pc_mux_i, exc_pc_mux_i, exc_vec_pc_mux_i, jump_target_ex_i;
input dbg_jump_addr_i, halt_if_i, id_ready_i;
input instr_req_o, instr_addr_o, instr_valid_id_o, instr_rdata_id_o, is_compressed_id_o;
input illegal_c_insn_id_o, pc_if_o, pc_id_o, if_valid_o, if_busy_o, perf_imiss_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
