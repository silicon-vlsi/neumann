`timescale 1ns/1ps
interface Controller_interface
(
    input logic clk
);
logic rst_n;
logic ctrl_ack_i;
logic ctrl_kill_i;
logic irq_i;
logic [4:0] irq_id_i;
logic m_IE_i;
logic irq_req_ctrl_o;
logic [4:0] irq_id_ctrl_o;

clocking drv_cb @(posedge clk);
default output #1;
output rst_n;
output ctrl_ack_i, ctrl_kill_i, irq_i, irq_id_i, m_IE_i;
endclocking

clocking mon_cb @(negedge clk);
default input #1step; 
input rst_n;
input ctrl_ack_i, ctrl_kill_i, irq_i, irq_id_i, m_IE_i;
input irq_req_ctrl_o, irq_id_ctrl_o;
endclocking

modport DRV(clocking drv_cb,input clk);
modport MON(clocking mon_cb,input clk);

endinterface