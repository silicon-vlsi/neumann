class transaction;

    rand bit [5:0]  operator;
    rand bit [31:0] operand_a;
    rand bit [31:0] operand_b;

    bit [31:0] result;
    bit        comparison_result;
    bit        is_equal_result;
    bit [31:0] adder_result;

    bit [31:0] exp_result;
    bit        exp_cmp;

    constraint c_operands {
        operand_a dist { 32'h0000_0000 :/ 5, 32'hFFFF_FFFF :/ 5,
                         32'h7FFF_FFFF :/ 5, 32'h8000_0000 :/ 5,
                         [1:32'hFFFF_FFFE] :/ 80 };
        operand_b dist { 32'h0000_0000 :/ 5, 32'hFFFF_FFFF :/ 5,
                         32'h7FFF_FFFF :/ 5, 32'h8000_0000 :/ 5,
                         [1:32'hFFFF_FFFE] :/ 80 };
    }

    function transaction copy();
        copy = new();
        copy.operator          = operator;
        copy.operand_a         = operand_a;
        copy.operand_b         = operand_b;
        copy.result            = result;
        copy.comparison_result = comparison_result;
        copy.is_equal_result   = is_equal_result;
        copy.adder_result      = adder_result;
        copy.exp_result        = exp_result;
        copy.exp_cmp           = exp_cmp;
    endfunction

    function void print(string tag = "");
        $display("[%s] op=%0h a=%08h b=%08h | res=%08h exp=%08h cmp=%b eq=%b",
                 tag, operator, operand_a, operand_b,
                 result, exp_result, comparison_result, is_equal_result);
    endfunction

endclass
