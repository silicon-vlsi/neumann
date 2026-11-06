class Ex_Transaction;
    rand logic [`ALU_OP_WIDTH-1:0] alu_operator_i;
    rand logic [31:0] alu_operand_a_i;
    rand logic [31:0] alu_operand_b_i;
    rand logic lsu_en_i;
    rand logic lsu_ready_ex_i;

    logic [31:0] alu_adder_result_ex_o;
    logic [31:0] regfile_wdata_ex_o;
    logic [31:0] jump_target_o;
    logic branch_decision_o;
    logic ex_ready_o;

    constraint c_op
    {
        alu_operator_i dist {
            `ALU_ADD := 6, `ALU_SUB := 6, `ALU_AND := 4, `ALU_OR := 4, `ALU_XOR := 4,
            `ALU_SLL := 5, `ALU_SRL := 5, `ALU_SRA := 5,
            `ALU_EQ := 4, `ALU_NE := 4,
            `ALU_GTU := 3, `ALU_GEU := 3, `ALU_LTU := 4, `ALU_LEU := 3,
            `ALU_GTS := 3, `ALU_GES := 4, `ALU_LTS := 4, `ALU_LES := 3,
            `ALU_SLTS := 4, `ALU_SLTU := 4, `ALU_SLETS := 3, `ALU_SLETU := 3,
            [0:63] :/ 4
        };
    }

    constraint c_operands
    {
        alu_operand_a_i dist { 32'h0 := 5, 32'hFFFF_FFFF := 5, 32'h7FFF_FFFF := 5, 32'h8000_0000 := 5, [0:32'hFFFF_FFFF] :/ 80 };
        alu_operand_b_i dist { 32'h0 := 5, 32'hFFFF_FFFF := 5, 32'h7FFF_FFFF := 5, 32'h8000_0000 := 5, [0:31] := 10, [0:32'hFFFF_FFFF] :/ 70 };
    }

    constraint c_lsu
    {
        lsu_en_i dist {1 := 30, 0 := 70};
        lsu_ready_ex_i dist {1 := 50, 0 := 50};
    }

    function void display(string tag="TX");
        $display("[%s] op=%0h a=%h b=%h lsu_en=%b lsu_rdy=%b | adder=%h wdata=%h jt=%h br=%b rdy=%b",
                 tag, alu_operator_i, alu_operand_a_i, alu_operand_b_i, lsu_en_i, lsu_ready_ex_i,
                 alu_adder_result_ex_o, regfile_wdata_ex_o, jump_target_o, branch_decision_o, ex_ready_o);
    endfunction

    function Ex_Transaction do_copy();
        Ex_Transaction copy;
        copy = new();
        copy.alu_operator_i = this.alu_operator_i;
        copy.alu_operand_a_i = this.alu_operand_a_i;
        copy.alu_operand_b_i = this.alu_operand_b_i;
        copy.lsu_en_i = this.lsu_en_i;
        copy.lsu_ready_ex_i = this.lsu_ready_ex_i;
        copy.alu_adder_result_ex_o = this.alu_adder_result_ex_o;
        copy.regfile_wdata_ex_o = this.regfile_wdata_ex_o;
        copy.jump_target_o = this.jump_target_o;
        copy.branch_decision_o = this.branch_decision_o;
        copy.ex_ready_o = this.ex_ready_o;
        return copy;
    endfunction
endclass
