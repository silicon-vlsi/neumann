`timescale 1ns/1ps
`include "rv32i_defines.vh"
interface Dbg_interface
(
    input logic clk
);
logic rst_n;
logic debug_req_i;
logic [14:0] debug_addr_i;
logic debug_we_i;
logic [31:0] debug_wdata_i;
logic debug_halt_i;
logic debug_resume_i;
logic trap_i;
logic [5:0] exc_cause_i;
logic dbg_ack_i;
logic [31:0] regfile_rdata_i;
logic [31:0] csr_rdata_i;
logic [31:0] pc_if_i;
logic [31:0] pc_id_i;
logic instr_valid_id_i;
logic sleeping_i;
logic debug_gnt_o;
logic debug_rvalid_o;
logic [31:0] debug_rdata_o;
logic debug_halted_o;
logic [`DBG_SETS_W-1:0] settings_o;
logic stall_o;
logic dbg_req_o;
logic regfile_rreq_o;
logic [4:0] regfile_raddr_o;
logic regfile_wreq_o;
logic [4:0] regfile_waddr_o;
logic [31:0] regfile_wdata_o;
logic csr_req_o;
logic [11:0] csr_addr_o;
logic csr_we_o;
logic [31:0] csr_wdata_o;
logic jump_req_o;
logic [31:0] jump_addr_o;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n, debug_req_i, debug_addr_i, debug_we_i, debug_wdata_i, debug_halt_i, debug_resume_i;
output trap_i, exc_cause_i, dbg_ack_i, regfile_rdata_i, csr_rdata_i, pc_if_i, pc_id_i;
output instr_valid_id_i, sleeping_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input rst_n, debug_req_i, debug_addr_i, debug_we_i, debug_wdata_i, debug_halt_i, debug_resume_i;
input trap_i, exc_cause_i, dbg_ack_i, regfile_rdata_i, csr_rdata_i, pc_if_i, pc_id_i;
input instr_valid_id_i, sleeping_i;
input debug_gnt_o, debug_rvalid_o, debug_rdata_o, debug_halted_o, settings_o, stall_o, dbg_req_o;
input regfile_rreq_o, regfile_raddr_o, regfile_wreq_o, regfile_waddr_o, regfile_wdata_o;
input csr_req_o, csr_addr_o, csr_we_o, csr_wdata_o, jump_req_o, jump_addr_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
