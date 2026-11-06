`include "rv32i_defines.vh"
module Ex_Assertions (
    input logic                     clk,
    input logic [`ALU_OP_WIDTH-1:0] alu_operator_i,
    input logic [31:0]              alu_operand_a_i,
    input logic [31:0]              alu_operand_b_i,
    input logic [31:0]              alu_adder_result_ex_o,
    input logic [31:0]              regfile_wdata_ex_o,
    input logic [31:0]              jump_target_o,
    input logic                     branch_decision_o,
    input logic                     lsu_en_i,
    input logic                     lsu_ready_ex_i,
    input logic                     ex_ready_o
);

    property p_jump_eq_adder;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) jump_target_o == alu_adder_result_ex_o;
    endproperty
    a_jump_eq_adder : assert property (p_jump_eq_adder)
        else $error("EX: jump_target_o != adder result");

    property p_ready_no_lsu;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) !lsu_en_i |-> ex_ready_o;
    endproperty
    a_ready_no_lsu : assert property (p_ready_no_lsu)
        else $error("EX: ex_ready_o low without an LSU access");

    property p_ready_lsu;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) lsu_en_i |-> (ex_ready_o == lsu_ready_ex_i);
    endproperty
    a_ready_lsu : assert property (p_ready_lsu)
        else $error("EX: ex_ready_o does not follow lsu_ready_ex_i");

    property p_add;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) (alu_operator_i == `ALU_ADD) |-> (regfile_wdata_ex_o == alu_operand_a_i + alu_operand_b_i);
    endproperty
    a_add : assert property (p_add)
        else $error("EX: ADD result wrong");

    property p_sub;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) (alu_operator_i == `ALU_SUB) |-> (regfile_wdata_ex_o == alu_operand_a_i - alu_operand_b_i);
    endproperty
    a_sub : assert property (p_sub)
        else $error("EX: SUB result wrong");

    property p_eq_branch;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) (alu_operator_i == `ALU_EQ) |-> (branch_decision_o == (alu_operand_a_i == alu_operand_b_i));
    endproperty
    a_eq_branch : assert property (p_eq_branch)
        else $error("EX: BEQ decision wrong");

    property p_ne_branch;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) (alu_operator_i == `ALU_NE) |-> (branch_decision_o == (alu_operand_a_i != alu_operand_b_i));
    endproperty
    a_ne_branch : assert property (p_ne_branch)
        else $error("EX: BNE decision wrong");

    property p_no_x_out;
        @(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) !$isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i}) |->
            !$isunknown({alu_adder_result_ex_o, regfile_wdata_ex_o, jump_target_o, branch_decision_o});
    endproperty
    a_no_x_out : assert property (p_no_x_out)
        else $error("EX: X/Z on outputs");

    c_stall    : cover property (@(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) lsu_en_i && !lsu_ready_ex_i);
    c_lsu_done : cover property (@(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) lsu_en_i && lsu_ready_ex_i);
    c_taken    : cover property (@(posedge clk) disable iff ($isunknown({alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i})) (alu_operator_i == `ALU_LTS) && branch_decision_o);

endmodule

bind rv32i_ex_block Ex_Assertions u_assert (
    .clk                   (clk),
    .alu_operator_i        (alu_operator_i),
    .alu_operand_a_i       (alu_operand_a_i),
    .alu_operand_b_i       (alu_operand_b_i),
    .alu_adder_result_ex_o (alu_adder_result_ex_o),
    .regfile_wdata_ex_o    (regfile_wdata_ex_o),
    .jump_target_o         (jump_target_o),
    .branch_decision_o     (branch_decision_o),
    .lsu_en_i              (lsu_en_i),
    .lsu_ready_ex_i        (lsu_ready_ex_i),
    .ex_ready_o            (ex_ready_o)
);
