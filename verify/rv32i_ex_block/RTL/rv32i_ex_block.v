`include "rv32i_defines.vh"
 
module rv32i_ex_block
(
    input clk,
    input rst_n,
    input  [5:0]  alu_operator_i,        
    input  [31:0] alu_operand_a_i,
    input  [31:0] alu_operand_b_i,
    output [31:0] alu_adder_result_ex_o,
    output [31:0] regfile_wdata_ex_o,
    output [31:0] jump_target_o,
    output branch_decision_o,
    input  lsu_en_i,
    input  lsu_ready_ex_i,      
    output reg ex_ready_o           
);
    wire [31:0] alu_result;
    wire alu_cmp_result;
    assign regfile_wdata_ex_o = alu_result;
    assign branch_decision_o = alu_cmp_result;
    assign jump_target_o = alu_adder_result_ex_o;
    rv32i_alu alu_i
    (
        .operator_i (alu_operator_i),
        .operand_a_i(alu_operand_a_i),
        .operand_b_i(alu_operand_b_i),
        .adder_result_o(alu_adder_result_ex_o),
        .result_o(alu_result),
        .comparison_result_o(alu_cmp_result),
        .is_equal_result_o()                 // not needed here; branches use comparison_result_o
    );
    always @(*) begin
         if (lsu_en_i)
            ex_ready_o = lsu_ready_ex_i;
        else
            ex_ready_o = 1'b1;
    end
endmodule