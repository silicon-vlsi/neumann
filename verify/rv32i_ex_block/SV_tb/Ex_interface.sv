`timescale 1ns/1ps
`include "rv32i_defines.vh"
interface Ex_interface
(
    input logic clk
);
logic valid;
logic rst_n;
logic [`ALU_OP_WIDTH-1:0] alu_operator_i;
logic [31:0] alu_operand_a_i;
logic [31:0] alu_operand_b_i;
logic lsu_en_i;
logic lsu_ready_ex_i;
logic [31:0] alu_adder_result_ex_o;
logic [31:0] regfile_wdata_ex_o;
logic [31:0] jump_target_o;
logic branch_decision_o;
logic ex_ready_o;

clocking drv_cb @(posedge clk);
default output #1;
output valid, rst_n;
output alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input valid, rst_n;
input alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i;
input alu_adder_result_ex_o, regfile_wdata_ex_o, jump_target_o, branch_decision_o, ex_ready_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
