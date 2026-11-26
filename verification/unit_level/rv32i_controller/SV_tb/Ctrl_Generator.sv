`include "rv32i_defines.vh"
class Ctrl_Generator;
    mailbox #(Ctrl_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    function new(mailbox #(Ctrl_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    function Ctrl_Transaction nop();
        Ctrl_Transaction tx;
        tx = new();
        tx.fetch_enable_i    = 1;
        tx.illegal_insn_i    = 0;
        tx.ecall_insn_i      = 0;
        tx.mret_insn_i       = 0;
        tx.pipe_flush_i      = 0;
        tx.ebrk_insn_i       = 0;
        tx.csr_status_i      = 0;
        tx.instr_valid_i     = 1;
        tx.data_misaligned_i = 0;
        tx.branch_in_id_i    = 0;
        tx.branch_taken_ex_i = 0;
        tx.branch_set_i      = 0;
        tx.jump_set_i        = 0;
        tx.instr_multicyle_i = 0;
        tx.irq_req_ctrl_i    = 0;
        tx.irq_id_ctrl_i     = 0;
        tx.m_IE_i            = 0;
        tx.dbg_req_i         = 0;
        tx.dbg_stall_i       = 0;
        tx.dbg_jump_req_i    = 0;
        tx.dbg_settings_i    = 0;
        tx.id_ready_i        = 1;
        return tx;
    endfunction

    task put(Ctrl_Transaction tx);
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task run_nop(int n);
        repeat (n) put(nop());
    endtask

    task boot();
        Ctrl_Transaction tx;
        tx = nop();
        tx.fetch_enable_i = 0;
        repeat (3) put(tx);
        run_nop(4);
    endtask

    task flush_with(string kind, bit fe, bit dbg);
        Ctrl_Transaction tx;
        tx = nop();
        case (kind)
            "ecall":   tx.ecall_insn_i   = 1;
            "illegal": tx.illegal_insn_i = 1;
            "mret":    tx.mret_insn_i    = 1;
            "ebreak":  tx.ebrk_insn_i    = 1;
            "csr":     tx.csr_status_i   = 1;
            "wfi":     tx.pipe_flush_i   = 1;
        endcase
        tx.dbg_settings_i = $urandom();
        put(tx);
        tx.fetch_enable_i = fe;
        tx.dbg_req_i      = dbg;
        put(tx);
        run_nop(2);
    endtask

    task irq(bit en, bit multi, bit br, logic [4:0] id);
        Ctrl_Transaction tx;
        tx = nop();
        tx.irq_req_ctrl_i    = 1;
        tx.irq_id_ctrl_i     = id;
        tx.m_IE_i            = en;
        tx.instr_multicyle_i = multi;
        tx.branch_in_id_i    = br;
        put(tx);
        tx.irq_req_ctrl_i = 0;
        put(tx);
        run_nop(2);
    endtask

    task debug_session(bit jump);
        Ctrl_Transaction tx;
        tx = nop();
        tx.dbg_req_i = 1;
        put(tx);
        tx.dbg_req_i   = 0;
        tx.dbg_stall_i = 1;
        repeat (3) put(tx);
        if (jump) begin
            tx.dbg_jump_req_i = 1;
            put(tx);
            tx.dbg_jump_req_i = 0;
        end
        repeat (2) put(tx);
        tx.dbg_stall_i = 0;
        put(tx);
        run_nop(2);
    endtask

    task sleep_and_wake(bit by_irq, bit dbg);
        Ctrl_Transaction tx;
        tx = nop();
        tx.pipe_flush_i = 1;
        put(tx);
        tx.fetch_enable_i = 0;
        put(tx);
        tx.pipe_flush_i  = 0;
        tx.instr_valid_i = 0;
        repeat (4) put(tx);
        if (dbg) begin
            tx.dbg_req_i = 1;
            put(tx);
            tx.dbg_req_i   = 0;
            tx.dbg_stall_i = 1;
            repeat (2) put(tx);
            tx.dbg_jump_req_i = 1;
            put(tx);
            tx.dbg_jump_req_i = 0;
            put(tx);
            tx.dbg_stall_i = 0;
            put(tx);
            tx.fetch_enable_i = 0;
            repeat (2) put(tx);
        end
        if (by_irq) begin
            tx.irq_req_ctrl_i = 1;
            tx.m_IE_i         = 1;
            tx.irq_id_ctrl_i  = $urandom();
        end else
            tx.fetch_enable_i = 1;
        put(tx);
        tx.irq_req_ctrl_i = 0;
        tx.fetch_enable_i = 1;
        tx.instr_valid_i  = 1;
        run_nop(4);
    endtask

    task directed();
        string kinds[$];
        Ctrl_Transaction tx;
        kinds = '{"ecall", "illegal", "mret", "ebreak", "csr", "wfi"};
        boot();
        repeat (4) begin
            tx = nop(); tx.branch_set_i = 1; tx.dbg_settings_i = 1; put(tx);
            tx = nop(); tx.jump_set_i = 1; put(tx);
            tx = nop(); tx.branch_set_i = 1; tx.dbg_req_i = 1; put(tx);
            tx = nop(); tx.dbg_stall_i = 1; put(tx); put(tx);
            tx = nop(); put(tx);
            tx = nop(); tx.data_misaligned_i = 1; put(tx);
            tx = nop(); tx.instr_valid_i = 0; put(tx);
            tx = nop(); tx.id_ready_i = 0; put(tx);
        end
        foreach (kinds[k]) begin
            flush_with(kinds[k], 1, 0);
            flush_with(kinds[k], 1, 1);
            debug_session(0);
            flush_with(kinds[k], 0, 1);
            debug_session(1);
            flush_with(kinds[k], 0, 0);
            run_nop(3);
        end
        irq(1, 0, 0, 5'd7);
        irq(1, 1, 0, 5'd11);
        irq(1, 0, 1, 5'd31);
        irq(0, 0, 0, 5'd3);
        tx = nop(); tx.instr_valid_i = 0; tx.irq_req_ctrl_i = 1; tx.m_IE_i = 1; tx.irq_id_ctrl_i = 5'd9; put(tx);
        run_nop(3);
        debug_session(0);
        debug_session(1);
        tx = nop(); tx.dbg_req_i = 1; tx.branch_taken_ex_i = 1; put(tx);
        tx = nop(); tx.dbg_req_i = 1; tx.id_ready_i = 0; put(tx);
        tx = nop(); tx.dbg_req_i = 1; put(tx);
        tx = nop(); tx.dbg_stall_i = 0; put(tx);
        run_nop(3);
        sleep_and_wake(0, 0);
        sleep_and_wake(1, 0);
        sleep_and_wake(0, 1);
        sleep_and_wake(1, 1);
    endtask

    task run();
        Ctrl_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d cycles", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            put(tx);
        end
        done = 1;
    endtask
endclass
