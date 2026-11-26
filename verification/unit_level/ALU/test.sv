class test;

    environment env;
    virtual alu_if vif;

    function new(virtual alu_if vif);
        this.vif = vif;
        env = new(vif);
    endfunction

    function void configure();
        env.gen.op_list = '{
            `ALU_ADD, `ALU_SUB, `ALU_AND, `ALU_OR,  `ALU_XOR,
            `ALU_SLL, `ALU_SRL, `ALU_SRA,
            `ALU_EQ,  `ALU_NE,
            `ALU_GTU, `ALU_GEU, `ALU_LTU, `ALU_LEU,
            `ALU_GTS, `ALU_GES, `ALU_LTS, `ALU_LES,
            `ALU_SLTS,`ALU_SLTU,`ALU_SLETS,`ALU_SLETU
        };
        if (!$value$plusargs("num_trans=%d", env.gen.num_per_op)) begin
            env.gen.num_per_op = 200;
        end
    endfunction

    task run();
        configure();
        env.run();
    endtask

endclass
