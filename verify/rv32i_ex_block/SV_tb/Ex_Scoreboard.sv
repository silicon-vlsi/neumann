class Ex_Scoreboard;
    mailbox #(Ex_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;

    function new(mailbox #(Ex_Transaction) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    function bit is_sub_op(logic [5:0] op);
        case (op)
            `ALU_SUB, `ALU_EQ, `ALU_NE, `ALU_GTU, `ALU_GEU, `ALU_LTU, `ALU_LEU,
            `ALU_GTS, `ALU_GES, `ALU_LTS, `ALU_LES,
            `ALU_SLTS, `ALU_SLTU, `ALU_SLETS, `ALU_SLETU: is_sub_op = 1'b1;
            default: is_sub_op = 1'b0;
        endcase
    endfunction

    function bit is_cmp_op(logic [5:0] op);
        case (op)
            `ALU_EQ, `ALU_NE, `ALU_GTU, `ALU_GEU, `ALU_LTU, `ALU_LEU,
            `ALU_GTS, `ALU_GES, `ALU_LTS, `ALU_LES,
            `ALU_SLTS, `ALU_SLTU, `ALU_SLETS, `ALU_SLETU: is_cmp_op = 1'b1;
            default: is_cmp_op = 1'b0;
        endcase
    endfunction

    function bit ref_cmp(logic [5:0] op, logic [31:0] a, logic [31:0] b);
        logic signed [31:0] sa;
        logic signed [31:0] sb;
        sa = a;
        sb = b;
        case (op)
            `ALU_EQ   : ref_cmp = (a == b);
            `ALU_NE   : ref_cmp = (a != b);
            `ALU_GTU  : ref_cmp = (a >  b);
            `ALU_GEU  : ref_cmp = (a >= b);
            `ALU_LTU  : ref_cmp = (a <  b);
            `ALU_LEU  : ref_cmp = (a <= b);
            `ALU_GTS  : ref_cmp = (sa >  sb);
            `ALU_GES  : ref_cmp = (sa >= sb);
            `ALU_LTS  : ref_cmp = (sa <  sb);
            `ALU_LES  : ref_cmp = (sa <= sb);
            `ALU_SLTS : ref_cmp = (sa <  sb);
            `ALU_SLTU : ref_cmp = (a <  b);
            `ALU_SLETS: ref_cmp = (sa <= sb);
            `ALU_SLETU: ref_cmp = (a <= b);
            default   : ref_cmp = ((a + b) == 32'h0);
        endcase
    endfunction

    function logic [31:0] ref_result(logic [5:0] op, logic [31:0] a, logic [31:0] b);
        logic signed [31:0] sa;
        sa = a;
        case (op)
            `ALU_ADD: ref_result = a + b;
            `ALU_SUB: ref_result = a - b;
            `ALU_AND: ref_result = a & b;
            `ALU_OR : ref_result = a | b;
            `ALU_XOR: ref_result = a ^ b;
            `ALU_SLL: ref_result = a << b[4:0];
            `ALU_SRL: ref_result = a >> b[4:0];
            `ALU_SRA: ref_result = sa >>> b[4:0];
            default : ref_result = is_cmp_op(op) ? {31'b0, ref_cmp(op, a, b)} : 32'h0;
        endcase
    endfunction

    task run();
        Ex_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Ex_Transaction tx);
        logic [31:0] exp_adder;
        logic [31:0] exp_wdata;
        logic        exp_ready;
        string       diff;
        diff = "";
        exp_adder = is_sub_op(tx.alu_operator_i) ? tx.alu_operand_a_i - tx.alu_operand_b_i
                                                 : tx.alu_operand_a_i + tx.alu_operand_b_i;
        exp_wdata = ref_result(tx.alu_operator_i, tx.alu_operand_a_i, tx.alu_operand_b_i);
        exp_ready = tx.lsu_en_i ? tx.lsu_ready_ex_i : 1'b1;

        if (tx.alu_adder_result_ex_o !== exp_adder)
            diff = {diff, $sformatf(" adder exp=%h got=%h", exp_adder, tx.alu_adder_result_ex_o)};
        if (tx.jump_target_o !== exp_adder)
            diff = {diff, $sformatf(" jump_target exp=%h got=%h", exp_adder, tx.jump_target_o)};
        if (tx.regfile_wdata_ex_o !== exp_wdata)
            diff = {diff, $sformatf(" wdata exp=%h got=%h", exp_wdata, tx.regfile_wdata_ex_o)};
        if (is_cmp_op(tx.alu_operator_i) && tx.branch_decision_o !== ref_cmp(tx.alu_operator_i, tx.alu_operand_a_i, tx.alu_operand_b_i))
            diff = {diff, $sformatf(" branch exp=%b got=%b", ref_cmp(tx.alu_operator_i, tx.alu_operand_a_i, tx.alu_operand_b_i), tx.branch_decision_o)};
        if (tx.ex_ready_o !== exp_ready)
            diff = {diff, $sformatf(" ex_ready exp=%b got=%b", exp_ready, tx.ex_ready_o)};

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH op=%0h a=%h b=%h lsu_en=%b lsu_rdy=%b :%s",
                   tx.alu_operator_i, tx.alu_operand_a_i, tx.alu_operand_b_i,
                   tx.lsu_en_i, tx.lsu_ready_ex_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d",
                 total_count, pass_count, fail_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
