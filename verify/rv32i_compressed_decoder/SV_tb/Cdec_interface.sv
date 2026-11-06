`timescale 1ns/1ps
interface Cdec_interface
(
    input logic clk
);
logic valid;
logic [31:0] instr_i;
logic [31:0] instr_o;
logic is_compressed_o;
logic illegal_instr_o;

clocking drv_cb @(posedge clk);
default output #1;
output valid, instr_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input valid, instr_i;
input instr_o, is_compressed_o, illegal_instr_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
