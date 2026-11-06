`timescale 1ns/1ps
interface alu_if #(parameter OP_W = 6) (input logic clk);

    logic [OP_W-1:0] operator_i;
    logic [31:0]     operand_a_i;
    logic [31:0]     operand_b_i;
    logic [31:0]     adder_result_o;
    logic [31:0]     result_o;
    logic            comparison_result_o;
    logic            is_equal_result_o;

    clocking drv_cb @(posedge clk);
        default output #1;
        output operator_i, operand_a_i, operand_b_i;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input operator_i, operand_a_i, operand_b_i;
        input result_o, comparison_result_o, is_equal_result_o, adder_result_o;
    endclocking

    modport DRV (clocking drv_cb, input clk);
    modport MON (clocking mon_cb, input clk);

endinterface
