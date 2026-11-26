class coverage_inf;

    mailbox #(transaction) mon2cov;

    bit [5:0]  s_op;
    bit [31:0] s_a, s_b;
    bit        s_cmp, s_eq;

    covergroup cg;
        option.per_instance = 1;

        cp_op : coverpoint s_op {
            bins add={`ALU_ADD}; bins sub={`ALU_SUB};
            bins b_and={`ALU_AND}; bins b_or={`ALU_OR}; bins b_xor={`ALU_XOR};
            bins sll={`ALU_SLL}; bins srl={`ALU_SRL}; bins sra={`ALU_SRA};
            bins eq={`ALU_EQ}; bins ne={`ALU_NE};
            bins gtu={`ALU_GTU}; bins geu={`ALU_GEU};
            bins ltu={`ALU_LTU}; bins leu={`ALU_LEU};
            bins gts={`ALU_GTS}; bins ges={`ALU_GES};
            bins lts={`ALU_LTS}; bins les={`ALU_LES};
            bins slts={`ALU_SLTS}; bins sltu={`ALU_SLTU};
            bins slets={`ALU_SLETS}; bins sletu={`ALU_SLETU};
        }
        cp_a : coverpoint s_a {
            bins zero={32'h0}; bins one={32'h1}; bins ones={32'hFFFF_FFFF};
            bins maxp={32'h7FFF_FFFF}; bins minn={32'h8000_0000};
            bins mid=default;
        }
        cp_b : coverpoint s_b {
            bins zero={32'h0}; bins one={32'h1}; bins ones={32'hFFFF_FFFF};
            bins maxp={32'h7FFF_FFFF}; bins minn={32'h8000_0000};
            bins mid=default;
        }
        cp_sa : coverpoint s_a[31] { bins pos={0}; bins neg={1}; }
        cp_sb : coverpoint s_b[31] { bins pos={0}; bins neg={1}; }
        cp_cmp : coverpoint s_cmp { bins lo={0}; bins hi={1}; }
        cp_eq  : coverpoint s_eq  { bins ne={0};  bins eq={1}; }

        x_op_cmp : cross cp_op, cp_cmp;
        x_sign   : cross cp_sa, cp_sb;
    endgroup

    function new(mailbox #(transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        transaction tr;
        forever begin
            mon2cov.get(tr);
            s_op  = tr.operator;
            s_a   = tr.operand_a;
            s_b   = tr.operand_b;
            s_cmp = tr.comparison_result;
            s_eq  = tr.is_equal_result;
            cg.sample();
        end
    endtask

    function void report();
        $display("========== COVERAGE ==========");
        $display(" Functional coverage = %0.2f %%", cg.get_coverage());
        $display("==============================");
    endfunction

endclass
