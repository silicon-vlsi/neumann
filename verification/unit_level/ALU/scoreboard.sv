class scoreboard;

    mailbox #(transaction) mon2scb;
    int pass_count = 0;
    int fail_count = 0;

    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    function bit [31:0] ref_result(bit [5:0] op, bit [31:0] a, bit [31:0] b);
        logic signed [31:0] sa = a;
        logic signed [31:0] sb = b;
        logic [4:0]         sh = b[4:0];
        bit                 r;
        begin
            r = 1'b0;
            case (op)
                `ALU_ADD : ref_result = a + b;
                `ALU_SUB : ref_result = a - b;
                `ALU_AND : ref_result = a & b;
                `ALU_OR  : ref_result = a | b;
                `ALU_XOR : ref_result = a ^ b;
                `ALU_SLL : ref_result = a << sh;
                `ALU_SRL : ref_result = a >> sh;
                `ALU_SRA : ref_result = sa >>> sh;
                `ALU_SLTS  : begin r=(sa< sb); ref_result={31'b0,r}; end
                `ALU_SLTU  : begin r=(a < b);  ref_result={31'b0,r}; end
                `ALU_SLETS : begin r=(sa<=sb); ref_result={31'b0,r}; end
                `ALU_SLETU : begin r=(a <=b);  ref_result={31'b0,r}; end
                `ALU_EQ  : begin r=(a==b);  ref_result={31'b0,r}; end
                `ALU_NE  : begin r=(a!=b);  ref_result={31'b0,r}; end
                `ALU_GTU : begin r=(a> b);  ref_result={31'b0,r}; end
                `ALU_GEU : begin r=(a>=b);  ref_result={31'b0,r}; end
                `ALU_LTU : begin r=(a< b);  ref_result={31'b0,r}; end
                `ALU_LEU : begin r=(a<=b);  ref_result={31'b0,r}; end
                `ALU_GTS : begin r=(sa> sb);ref_result={31'b0,r}; end
                `ALU_GES : begin r=(sa>=sb);ref_result={31'b0,r}; end
                `ALU_LTS : begin r=(sa< sb);ref_result={31'b0,r}; end
                `ALU_LES : begin r=(sa<=sb);ref_result={31'b0,r}; end
                default  : ref_result = 32'b0;
            endcase
        end
    endfunction

    function bit ref_cmp(bit [5:0] op, bit [31:0] a, bit [31:0] b);
        logic signed [31:0] sa = a;
        logic signed [31:0] sb = b;
        case (op)
            `ALU_EQ  : ref_cmp=(a==b);   `ALU_NE  : ref_cmp=(a!=b);
            `ALU_GTU : ref_cmp=(a> b);   `ALU_GEU : ref_cmp=(a>=b);
            `ALU_LTU : ref_cmp=(a< b);   `ALU_LEU : ref_cmp=(a<=b);
            `ALU_GTS : ref_cmp=(sa> sb); `ALU_GES : ref_cmp=(sa>=sb);
            `ALU_LTS : ref_cmp=(sa< sb); `ALU_LES : ref_cmp=(sa<=sb);
            `ALU_SLTS: ref_cmp=(sa< sb); `ALU_SLTU: ref_cmp=(a< b);
            `ALU_SLETS:ref_cmp=(sa<=sb); `ALU_SLETU:ref_cmp=(a<=b);
            default  : ref_cmp=(a==b);
        endcase
    endfunction

    function bit is_cmp_op(bit [5:0] op);
        case (op)
            `ALU_EQ,`ALU_NE,`ALU_GTU,`ALU_GEU,`ALU_LTU,`ALU_LEU,
            `ALU_GTS,`ALU_GES,`ALU_LTS,`ALU_LES,
            `ALU_SLTS,`ALU_SLTU,`ALU_SLETS,`ALU_SLETU: is_cmp_op = 1'b1;
            default: is_cmp_op = 1'b0;
        endcase
    endfunction

    task run();
        transaction tr;
        forever begin
            mon2scb.get(tr);
            tr.exp_result = ref_result(tr.operator, tr.operand_a, tr.operand_b);
            tr.exp_cmp    = ref_cmp   (tr.operator, tr.operand_a, tr.operand_b);

            if (tr.result !== tr.exp_result) begin
                fail_count++;
                $display("[SCB][FAIL] op=%0h a=%08h b=%08h got=%08h exp=%08h",
                         tr.operator, tr.operand_a, tr.operand_b,
                         tr.result, tr.exp_result);
            end else pass_count++;

            if (is_cmp_op(tr.operator) &&
                (tr.comparison_result !== tr.exp_cmp)) begin
                fail_count++;
                $display("[SCB][FAIL-CMP] op=%0h a=%08h b=%08h got=%b exp=%b",
                         tr.operator, tr.operand_a, tr.operand_b,
                         tr.comparison_result, tr.exp_cmp);
            end
        end
    endtask

    function void report();
        $display("========== SCOREBOARD ==========");
        $display(" PASS=%0d  FAIL=%0d", pass_count, fail_count);
        $display(" RESULT: %s", (fail_count==0)?"*** PASS ***":"*** FAIL ***");
        $display("================================");
    endfunction

endclass
