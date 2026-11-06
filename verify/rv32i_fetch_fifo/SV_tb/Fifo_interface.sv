`timescale 1ns/1ps
interface Fifo_interface
(
    input logic clk
);
logic rst_n;
logic clear_i;
logic [31:0] in_addr_i;
logic [31:0] in_rdata_i;
logic in_valid_i;
logic in_ready_o;
logic out_valid_o;
logic out_ready_i;
logic [31:0] out_rdata_o;
logic [31:0] out_addr_o;
logic out_valid_stored_o;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n, clear_i, in_addr_i, in_rdata_i, in_valid_i, out_ready_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step;
input rst_n, clear_i, in_addr_i, in_rdata_i, in_valid_i, out_ready_i;
input in_ready_o, out_valid_o, out_rdata_o, out_addr_o, out_valid_stored_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface
