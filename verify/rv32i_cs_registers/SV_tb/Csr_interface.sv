`timescale 1ns/1ps
interface Csr_interface
(
    input logic clk
);
logic rst_n;
logic [3:0] core_id_i;
logic [5:0] cluster_id_i;
logic [23:0] boot_addr_i;
logic csr_access_i;
logic [11:0] csr_addr_i;
logic [31:0] csr_wdata_i;
logic [1:0] csr_op_i;
logic [31:0] csr_rdata_o;
logic m_irq_enable_o;
logic [31:0] mepc_o;
logic [31:0] pc_if_i;
logic [31:0] pc_id_i;
logic csr_save_if_i;
logic csr_save_id_i;
logic csr_restore_mret_i;
logic [5:0] csr_cause_i;
logic csr_save_cause_i;
logic if_valid_i;
logic id_valid_i;
logic is_compressed_i;
logic is_decoding_i;
logic imiss_i;
logic pc_set_i;
logic jump_i;
logic branch_i;
logic branch_taken_i;
logic mem_load_i;
logic mem_store_i;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n, core_id_i, cluster_id_i, boot_addr_i;
output csr_access_i, csr_addr_i, csr_wdata_i, csr_op_i;
output pc_if_i, pc_id_i, csr_save_if_i, csr_save_id_i, csr_restore_mret_i, csr_cause_i, csr_save_cause_i;
output if_valid_i, id_valid_i, is_compressed_i, is_decoding_i, imiss_i, pc_set_i;
output jump_i, branch_i, branch_taken_i, mem_load_i, mem_store_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input rst_n, core_id_i, cluster_id_i, boot_addr_i;
input csr_access_i, csr_addr_i, csr_wdata_i, csr_op_i;
input pc_if_i, pc_id_i, csr_save_if_i, csr_save_id_i, csr_restore_mret_i, csr_cause_i, csr_save_cause_i;
input if_valid_i, id_valid_i, is_compressed_i, is_decoding_i, imiss_i, pc_set_i;
input jump_i, branch_i, branch_taken_i, mem_load_i, mem_store_i;
input csr_rdata_o, m_irq_enable_o, mepc_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
