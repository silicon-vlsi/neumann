class Ctrl_Driver;
    mailbox #(Ctrl_Transaction) gen2drv;
    virtual Ctrl_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    function new(mailbox #(Ctrl_Transaction) gen2drv, virtual Ctrl_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    task automatic reset();
        vif.drv_cb.rst_n <= 0;
        vif.drv_cb.fetch_enable_i <= 0;
        vif.drv_cb.illegal_insn_i <= 0;
        vif.drv_cb.ecall_insn_i <= 0;
        vif.drv_cb.mret_insn_i <= 0;
        vif.drv_cb.pipe_flush_i <= 0;
        vif.drv_cb.ebrk_insn_i <= 0;
        vif.drv_cb.csr_status_i <= 0;
        vif.drv_cb.instr_valid_i <= 0;
        vif.drv_cb.data_misaligned_i <= 0;
        vif.drv_cb.branch_in_id_i <= 0;
        vif.drv_cb.branch_taken_ex_i <= 0;
        vif.drv_cb.branch_set_i <= 0;
        vif.drv_cb.jump_set_i <= 0;
        vif.drv_cb.instr_multicyle_i <= 0;
        vif.drv_cb.irq_req_ctrl_i <= 0;
        vif.drv_cb.m_IE_i <= 0;
        vif.drv_cb.dbg_req_i <= 0;
        vif.drv_cb.dbg_stall_i <= 0;
        vif.drv_cb.dbg_jump_req_i <= 0;
        vif.drv_cb.id_ready_i <= 0;
        vif.drv_cb.irq_id_ctrl_i <= 0;
        vif.drv_cb.dbg_settings_i <= 0;
        repeat (3) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;
        @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] reset done");
    endtask

    task automatic drive(Ctrl_Transaction tx);
        vif.drv_cb.fetch_enable_i <= tx.fetch_enable_i;
        vif.drv_cb.illegal_insn_i <= tx.illegal_insn_i;
        vif.drv_cb.ecall_insn_i <= tx.ecall_insn_i;
        vif.drv_cb.mret_insn_i <= tx.mret_insn_i;
        vif.drv_cb.pipe_flush_i <= tx.pipe_flush_i;
        vif.drv_cb.ebrk_insn_i <= tx.ebrk_insn_i;
        vif.drv_cb.csr_status_i <= tx.csr_status_i;
        vif.drv_cb.instr_valid_i <= tx.instr_valid_i;
        vif.drv_cb.data_misaligned_i <= tx.data_misaligned_i;
        vif.drv_cb.branch_in_id_i <= tx.branch_in_id_i;
        vif.drv_cb.branch_taken_ex_i <= tx.branch_taken_ex_i;
        vif.drv_cb.branch_set_i <= tx.branch_set_i;
        vif.drv_cb.jump_set_i <= tx.jump_set_i;
        vif.drv_cb.instr_multicyle_i <= tx.instr_multicyle_i;
        vif.drv_cb.irq_req_ctrl_i <= tx.irq_req_ctrl_i;
        vif.drv_cb.m_IE_i <= tx.m_IE_i;
        vif.drv_cb.dbg_req_i <= tx.dbg_req_i;
        vif.drv_cb.dbg_stall_i <= tx.dbg_stall_i;
        vif.drv_cb.dbg_jump_req_i <= tx.dbg_jump_req_i;
        vif.drv_cb.id_ready_i <= tx.id_ready_i;
        vif.drv_cb.irq_id_ctrl_i <= tx.irq_id_ctrl_i;
        vif.drv_cb.dbg_settings_i <= tx.dbg_settings_i;
    endtask

    task automatic idle();
        @(vif.drv_cb);
        vif.drv_cb.instr_valid_i <= 0;
        vif.drv_cb.irq_req_ctrl_i <= 0;
        vif.drv_cb.dbg_req_i <= 0;
    endtask

    task run();
        Ctrl_Transaction tx;
        wait (init_done);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            drv_count++;
        end
    endtask
endclass
