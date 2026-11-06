`timescale 1ns/1ps
interface Pref_interface
(
    input logic clk
);
logic rst_n;
logic req_i;
logic branch_i;
logic [31:0] addr_i;
logic ready_i;
logic valid_o;
logic [31:0] rdata_o;
logic [31:0] addr_o;
logic instr_req_o;
logic instr_gnt_i;
logic [31:0] instr_addr_o;
logic [31:0] instr_rdata_i;
logic instr_rvalid_i;
logic busy_o;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n, req_i, branch_i, addr_i, ready_i;
output instr_gnt_i, instr_rdata_i, instr_rvalid_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input rst_n, req_i, branch_i, addr_i, ready_i;
input instr_gnt_i, instr_rdata_i, instr_rvalid_i;
input valid_o, rdata_o, addr_o, instr_req_o, instr_addr_o, busy_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
