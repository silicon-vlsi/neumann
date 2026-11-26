class Ctrl_Monitor;
    virtual Ctrl_interface vif;
    mailbox #(Ctrl_Transaction) mon2scb;
    mailbox #(Ctrl_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Ctrl_interface vif,
            mailbox #(Ctrl_Transaction) mon2scb,
            mailbox #(Ctrl_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Ctrl_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.rst_n = vif.mon_cb.rst_n;
            tx.fetch_enable_i = vif.mon_cb.fetch_enable_i;
            tx.illegal_insn_i = vif.mon_cb.illegal_insn_i;
            tx.ecall_insn_i = vif.mon_cb.ecall_insn_i;
            tx.mret_insn_i = vif.mon_cb.mret_insn_i;
            tx.pipe_flush_i = vif.mon_cb.pipe_flush_i;
            tx.ebrk_insn_i = vif.mon_cb.ebrk_insn_i;
            tx.csr_status_i = vif.mon_cb.csr_status_i;
            tx.instr_valid_i = vif.mon_cb.instr_valid_i;
            tx.data_misaligned_i = vif.mon_cb.data_misaligned_i;
            tx.branch_in_id_i = vif.mon_cb.branch_in_id_i;
            tx.branch_taken_ex_i = vif.mon_cb.branch_taken_ex_i;
            tx.branch_set_i = vif.mon_cb.branch_set_i;
            tx.jump_set_i = vif.mon_cb.jump_set_i;
            tx.instr_multicyle_i = vif.mon_cb.instr_multicyle_i;
            tx.irq_req_ctrl_i = vif.mon_cb.irq_req_ctrl_i;
            tx.m_IE_i = vif.mon_cb.m_IE_i;
            tx.dbg_req_i = vif.mon_cb.dbg_req_i;
            tx.dbg_stall_i = vif.mon_cb.dbg_stall_i;
            tx.dbg_jump_req_i = vif.mon_cb.dbg_jump_req_i;
            tx.id_ready_i = vif.mon_cb.id_ready_i;
            tx.irq_id_ctrl_i = vif.mon_cb.irq_id_ctrl_i;
            tx.dbg_settings_i = vif.mon_cb.dbg_settings_i;
            tx.ctrl_busy_o = vif.mon_cb.ctrl_busy_o;
            tx.first_fetch_o = vif.mon_cb.first_fetch_o;
            tx.is_decoding_o = vif.mon_cb.is_decoding_o;
            tx.deassert_we_o = vif.mon_cb.deassert_we_o;
            tx.instr_req_o = vif.mon_cb.instr_req_o;
            tx.pc_set_o = vif.mon_cb.pc_set_o;
            tx.irq_ack_o = vif.mon_cb.irq_ack_o;
            tx.exc_ack_o = vif.mon_cb.exc_ack_o;
            tx.exc_kill_o = vif.mon_cb.exc_kill_o;
            tx.csr_save_if_o = vif.mon_cb.csr_save_if_o;
            tx.csr_save_id_o = vif.mon_cb.csr_save_id_o;
            tx.csr_restore_mret_id_o = vif.mon_cb.csr_restore_mret_id_o;
            tx.csr_save_cause_o = vif.mon_cb.csr_save_cause_o;
            tx.dbg_ack_o = vif.mon_cb.dbg_ack_o;
            tx.dbg_trap_o = vif.mon_cb.dbg_trap_o;
            tx.halt_if_o = vif.mon_cb.halt_if_o;
            tx.halt_id_o = vif.mon_cb.halt_id_o;
            tx.perf_jump_o = vif.mon_cb.perf_jump_o;
            tx.perf_tbranch_o = vif.mon_cb.perf_tbranch_o;
            tx.pc_mux_o = vif.mon_cb.pc_mux_o;
            tx.exc_pc_mux_o = vif.mon_cb.exc_pc_mux_o;
            tx.irq_id_o = vif.mon_cb.irq_id_o;
            tx.exc_cause_o = vif.mon_cb.exc_cause_o;
            tx.csr_cause_o = vif.mon_cb.csr_cause_o;
            tx.operand_a_fw_mux_sel_o = vif.mon_cb.operand_a_fw_mux_sel_o;
            tx.dbg_cs = vif.mon_cb.dbg_cs;
            if (tx.pc_set_o || tx.dbg_ack_o || tx.irq_ack_o)
                tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
