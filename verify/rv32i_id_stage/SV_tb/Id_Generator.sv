`include "rv32i_defines.vh"
class Id_Generator;
    mailbox #(Id_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    function new(mailbox #(Id_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    function Id_Transaction step(int unsigned kind);
        Id_Transaction tx;
        tx = new();
        tx.kind                = kind;
        tx.next_instr          = Id_Transaction::make_instr(kind);
        tx.fetch_valid         = 1;
        tx.branch_decision_i   = $urandom_range(0, 1);
        tx.ex_ready_i          = 1;
        tx.data_misaligned_i   = 0;
        tx.misaligned_addr_i   = $urandom();
        tx.dbg_reg_rreq_i      = 0;
        tx.dbg_reg_raddr_i     = 0;
        tx.dbg_reg_wreq_i      = 0;
        tx.dbg_reg_waddr_i     = 0;
        tx.dbg_reg_wdata_i     = 0;
        tx.regfile_wdata_lsu_i = $urandom();
        tx.regfile_wdata_ex_i  = $urandom();
        tx.csr_rdata_i         = $urandom();
        return tx;
    endfunction

    task put(Id_Transaction tx);
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task init_regs();
        Id_Transaction tx;
        for (int r = 1; r < 32; r++) begin
            tx = step(0);
            tx.fetch_valid     = 0;
            tx.dbg_reg_wreq_i  = 1;
            tx.dbg_reg_waddr_i = r;
            tx.dbg_reg_wdata_i = $urandom();
            put(tx);
        end
    endtask

    task dump_regs();
        Id_Transaction tx;
        for (int r = 0; r < 32; r++) begin
            tx = step(0);
            tx.fetch_valid     = 0;
            tx.dbg_reg_rreq_i  = 1;
            tx.dbg_reg_raddr_i = r;
            put(tx);
        end
    endtask

    task directed();
        Id_Transaction tx;
        init_regs();
        for (int k = 0; k < 10; k++)
            repeat (30) put(step(k));
        for (int k = 0; k < 10; k++)
            repeat (30) begin
                tx = step(k);
                tx.ex_ready_i = ($urandom_range(0, 2) != 0);
                tx.fetch_valid = ($urandom_range(0, 4) != 0);
                put(tx);
            end
        repeat (40) begin
            tx = step($urandom_range(4, 5));
            tx.data_misaligned_i = ($urandom_range(0, 3) == 0);
            put(tx);
        end
        repeat (60) begin
            tx = step($urandom_range(0, 9));
            tx.dbg_reg_rreq_i  = ($urandom_range(0, 2) == 0);
            tx.dbg_reg_raddr_i = $urandom();
            put(tx);
        end
        repeat (20) begin
            tx = step($urandom_range(0, 9));
            tx.dbg_reg_rreq_i  = 1;
            tx.dbg_reg_raddr_i = $urandom();
            tx.dbg_reg_wreq_i  = 1;
            tx.dbg_reg_waddr_i = $urandom();
            tx.dbg_reg_wdata_i = $urandom();
            put(tx);
        end
        for (int k = 0; k < 40; k++) begin
            tx = step(6);
            tx.branch_decision_i = k[0];
            put(tx);
        end
        repeat (20) put(step(10));
        repeat (20) put(step(11));
        dump_regs();
    endtask

    task run();
        Id_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d cycles", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.next_instr = Id_Transaction::make_instr(tx.kind);
            put(tx);
        end
        dump_regs();
        done = 1;
    endtask
endclass
