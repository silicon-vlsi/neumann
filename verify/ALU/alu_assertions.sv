`include "rv32i_defines.vh"

module alu_assertions #(parameter OP_W = 4) (
    input logic              clk,
    input logic              rst_n,
    input logic [OP_W-1:0]   operator_i,
    input logic [31:0]       operand_a_i,
    input logic [31:0]       operand_b_i,
    input logic [31:0]       adder_result_o,
    input logic [31:0]       result_o,
    input logic              comparison_result_o,
    input logic              is_equal_result_o
);

    function automatic logic [31:0] gold_add(logic [31:0] a, b); gold_add = a + b; endfunction
    function automatic logic [31:0] gold_sub(logic [31:0] a, b); gold_sub = a - b; endfunction

    property p_no_x;
        @(posedge clk) disable iff (!rst_n)
        (!$isunknown({operator_i, operand_a_i, operand_b_i})) |->
        (!$isunknown(result_o));
    endproperty
    a_no_x : assert property (p_no_x)
        else $error("ALU: result_o is X/Z with known inputs");

    property p_add;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_ADD) |-> (result_o == gold_add(operand_a_i, operand_b_i));
    endproperty
    a_add : assert property (p_add)
        else $error("ALU: ADD mismatch a=%h b=%h res=%h",
                    operand_a_i, operand_b_i, result_o);

    property p_sub;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_SUB) |-> (result_o == gold_sub(operand_a_i, operand_b_i));
    endproperty
    a_sub : assert property (p_sub)
        else $error("ALU: SUB mismatch a=%h b=%h res=%h",
                    operand_a_i, operand_b_i, result_o);

    property p_equal;
        @(posedge clk) disable iff (!rst_n)
        (operator_i inside {`ALU_EQ, `ALU_NE}) |->
        (is_equal_result_o == (operand_a_i == operand_b_i));
    endproperty
    a_equal : assert property (p_equal)
        else $error("ALU: is_equal wrong a=%h b=%h eq=%b",
                    operand_a_i, operand_b_i, is_equal_result_o);

    property p_eq_cmp;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_EQ) |->
        (comparison_result_o == (operand_a_i == operand_b_i));
    endproperty
    a_eq_cmp : assert property (p_eq_cmp)
        else $error("ALU: EQ cmp wrong");

    property p_ne_cmp;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_NE) |->
        (comparison_result_o == (operand_a_i != operand_b_i));
    endproperty
    a_ne_cmp : assert property (p_ne_cmp)
        else $error("ALU: NE cmp wrong");

    property p_ltu;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_LTU) |->
        (comparison_result_o == (operand_a_i < operand_b_i));
    endproperty
    a_ltu : assert property (p_ltu)
        else $error("ALU: LTU cmp wrong");

    property p_lts;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_LTS) |->
        (comparison_result_o == ($signed(operand_a_i) < $signed(operand_b_i)));
    endproperty
    a_lts : assert property (p_lts)
        else $error("ALU: LTS cmp wrong");

    property p_slt_upper_zero;
        @(posedge clk) disable iff (!rst_n)
        (operator_i inside {`ALU_SLTS, `ALU_SLTU, `ALU_SLETS, `ALU_SLETU})
        |-> (result_o[31:1] == 31'b0);
    endproperty
    a_slt_upper : assert property (p_slt_upper_zero)
        else $error("ALU: SLT* upper bits nonzero res=%h", result_o);

    property p_and;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_AND) |-> (result_o == (operand_a_i & operand_b_i));
    endproperty
    a_and : assert property (p_and) else $error("ALU: AND wrong");

    property p_or;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_OR) |-> (result_o == (operand_a_i | operand_b_i));
    endproperty
    a_or : assert property (p_or) else $error("ALU: OR wrong");

    property p_xor;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_XOR) |-> (result_o == (operand_a_i ^ operand_b_i));
    endproperty
    a_xor : assert property (p_xor) else $error("ALU: XOR wrong");

    property p_sll;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_SLL) |->
        (result_o == (operand_a_i << operand_b_i[4:0]));
    endproperty
    a_sll : assert property (p_sll) else $error("ALU: SLL wrong");

    property p_srl;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_SRL) |->
        (result_o == (operand_a_i >> operand_b_i[4:0]));
    endproperty
    a_srl : assert property (p_srl) else $error("ALU: SRL wrong");

    property p_sra;
        @(posedge clk) disable iff (!rst_n)
        (operator_i == `ALU_SRA) |-> ($signed(result_o) == $signed(operand_a_i) >>> operand_b_i[4:0]);
    endproperty
    a_sra : assert property (p_sra) else $error("ALU: SRA wrong");

    c_add : cover property (@(posedge clk) operator_i == `ALU_ADD);
    c_sub : cover property (@(posedge clk) operator_i == `ALU_SUB);
    c_sll : cover property (@(posedge clk) operator_i == `ALU_SLL);
    c_lts : cover property (@(posedge clk) operator_i == `ALU_LTS);

endmodule
