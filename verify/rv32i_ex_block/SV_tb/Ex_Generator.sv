class Ex_Generator;
    mailbox #(Ex_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    logic [5:0]  ops[$];
    logic [31:0] corner[$];

    function new(mailbox #(Ex_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
        ops = '{`ALU_ADD, `ALU_SUB, `ALU_AND, `ALU_OR, `ALU_XOR, `ALU_SLL, `ALU_SRL, `ALU_SRA,
                `ALU_EQ, `ALU_NE, `ALU_GTU, `ALU_GEU, `ALU_LTU, `ALU_LEU,
                `ALU_GTS, `ALU_GES, `ALU_LTS, `ALU_LES,
                `ALU_SLTS, `ALU_SLTU, `ALU_SLETS, `ALU_SLETU};
        corner = '{32'h0, 32'h1, 32'h2, 32'h1F, 32'h20, 32'h7FFF_FFFE, 32'h7FFF_FFFF,
                   32'h8000_0000, 32'h8000_0001, 32'hFFFF_FFFE, 32'hFFFF_FFFF, 32'h5555_5555, 32'hAAAA_AAAA};
    endfunction

    task send(logic [5:0] op, logic [31:0] a, logic [31:0] b, logic en, logic rdy);
        Ex_Transaction tx;
        tx = new();
        tx.alu_operator_i  = op;
        tx.alu_operand_a_i = a;
        tx.alu_operand_b_i = b;
        tx.lsu_en_i        = en;
        tx.lsu_ready_ex_i  = rdy;
        tx.display("GEN");
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task directed();
        logic [31:0] r;
        foreach (ops[o]) begin
            foreach (corner[i])
                foreach (corner[j])
                    send(ops[o], corner[i], corner[j], 1'b0, 1'b0);
            repeat (20) begin
                r = $urandom();
                send(ops[o], r, r, 1'b0, 1'b0);
                send(ops[o], r, r + 1, 1'b0, 1'b0);
                send(ops[o], r + 1, r, 1'b0, 1'b0);
                send(ops[o], r, {~r[31], r[30:0]}, 1'b0, 1'b0);
            end
        end
        for (int s = 0; s < 64; s++) begin
            r = $urandom();
            send(`ALU_SLL, r, s, 1'b0, 1'b0);
            send(`ALU_SRL, r, s, 1'b0, 1'b0);
            send(`ALU_SRA, r | 32'h8000_0000, s, 1'b0, 1'b0);
        end
        for (int k = 0; k < 4; k++)
            send(`ALU_ADD, $urandom(), $urandom(), k[1], k[0]);
    endtask

    task run();
        Ex_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d transactions", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.display("GEN");
            gen2drv.put(tx.do_copy());
            gen_count++;
        end
        done = 1;
    endtask
endclass
