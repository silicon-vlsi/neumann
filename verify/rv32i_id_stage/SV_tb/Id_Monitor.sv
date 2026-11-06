class Id_Monitor;
    virtual Id_interface vif;
    mailbox #(Id_Transaction) mon2scb;
    mailbox #(Id_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Id_interface vif,
            mailbox #(Id_Transaction) mon2scb,
            mailbox #(Id_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Id_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.rst_n = vif.mon_cb.rst_n;
            tx.test_en_i = vif.mon_cb.test_en_i;
            tx.fetch_enable_i = vif.mon_cb.fetch_enable_i;
            tx.instr_valid_i = vif.mon_cb.instr_valid_i;
            tx.instr_rdata_i = vif.mon_cb.instr_rdata_i;
            tx.branch_decision_i = vif.mon_cb.branch_decision_i;
            tx.illegal_c_insn_i = vif.mon_cb.illegal_c_insn_i;
            tx.is_compressed_i = vif.mon_cb.is_compressed_i;
            tx.pc_id_i = vif.mon_cb.pc_id_i;
            tx.ex_ready_i = vif.mon_cb.ex_ready_i;
            tx.data_misaligned_i = vif.mon_cb.data_misaligned_i;
            tx.misaligned_addr_i = vif.mon_cb.misaligned_addr_i;
            tx.irq_i = vif.mon_cb.irq_i;
            tx.irq_id_i = vif.mon_cb.irq_id_i;
            tx.m_irq_enable_i = vif.mon_cb.m_irq_enable_i;
            tx.lsu_load_err_i = vif.mon_cb.lsu_load_err_i;
            tx.lsu_store_err_i = vif.mon_cb.lsu_store_err_i;
            tx.dbg_settings_i = vif.mon_cb.dbg_settings_i;
            tx.dbg_req_i = vif.mon_cb.dbg_req_i;
            tx.dbg_stall_i = vif.mon_cb.dbg_stall_i;
            tx.dbg_reg_rreq_i = vif.mon_cb.dbg_reg_rreq_i;
            tx.dbg_reg_raddr_i = vif.mon_cb.dbg_reg_raddr_i;
            tx.dbg_reg_wreq_i = vif.mon_cb.dbg_reg_wreq_i;
            tx.dbg_reg_waddr_i = vif.mon_cb.dbg_reg_waddr_i;
            tx.dbg_reg_wdata_i = vif.mon_cb.dbg_reg_wdata_i;
            tx.dbg_jump_req_i = vif.mon_cb.dbg_jump_req_i;
            tx.regfile_wdata_lsu_i = vif.mon_cb.regfile_wdata_lsu_i;
            tx.regfile_wdata_ex_i = vif.mon_cb.regfile_wdata_ex_i;
            tx.csr_rdata_i = vif.mon_cb.csr_rdata_i;
            tx.ctrl_busy_o = vif.mon_cb.ctrl_busy_o;
            tx.core_ctrl_firstfetch_o = vif.mon_cb.core_ctrl_firstfetch_o;
            tx.is_decoding_o = vif.mon_cb.is_decoding_o;
            tx.instr_req_o = vif.mon_cb.instr_req_o;
            tx.branch_in_ex_o = vif.mon_cb.branch_in_ex_o;
            tx.clear_instr_valid_o = vif.mon_cb.clear_instr_valid_o;
            tx.pc_set_o = vif.mon_cb.pc_set_o;
            tx.pc_mux_o = vif.mon_cb.pc_mux_o;
            tx.exc_pc_mux_o = vif.mon_cb.exc_pc_mux_o;
            tx.halt_if_o = vif.mon_cb.halt_if_o;
            tx.id_ready_o = vif.mon_cb.id_ready_o;
            tx.id_valid_o = vif.mon_cb.id_valid_o;
            tx.alu_operator_ex_o = vif.mon_cb.alu_operator_ex_o;
            tx.alu_operand_a_ex_o = vif.mon_cb.alu_operand_a_ex_o;
            tx.alu_operand_b_ex_o = vif.mon_cb.alu_operand_b_ex_o;
            tx.csr_access_ex_o = vif.mon_cb.csr_access_ex_o;
            tx.csr_op_ex_o = vif.mon_cb.csr_op_ex_o;
            tx.csr_cause_o = vif.mon_cb.csr_cause_o;
            tx.csr_save_if_o = vif.mon_cb.csr_save_if_o;
            tx.csr_save_id_o = vif.mon_cb.csr_save_id_o;
            tx.csr_restore_mret_id_o = vif.mon_cb.csr_restore_mret_id_o;
            tx.csr_save_cause_o = vif.mon_cb.csr_save_cause_o;
            tx.data_req_ex_o = vif.mon_cb.data_req_ex_o;
            tx.data_we_ex_o = vif.mon_cb.data_we_ex_o;
            tx.data_type_ex_o = vif.mon_cb.data_type_ex_o;
            tx.data_sign_ext_ex_o = vif.mon_cb.data_sign_ext_ex_o;
            tx.data_reg_offset_ex_o = vif.mon_cb.data_reg_offset_ex_o;
            tx.data_load_event_ex_o = vif.mon_cb.data_load_event_ex_o;
            tx.data_wdata_ex_o = vif.mon_cb.data_wdata_ex_o;
            tx.irq_ack_o = vif.mon_cb.irq_ack_o;
            tx.irq_id_o = vif.mon_cb.irq_id_o;
            tx.exc_cause_o = vif.mon_cb.exc_cause_o;
            tx.dbg_ack_o = vif.mon_cb.dbg_ack_o;
            tx.dbg_trap_o = vif.mon_cb.dbg_trap_o;
            tx.dbg_reg_rdata_o = vif.mon_cb.dbg_reg_rdata_o;
            tx.perf_jump_o = vif.mon_cb.perf_jump_o;
            tx.perf_branch_o = vif.mon_cb.perf_branch_o;
            tx.perf_tbranch_o = vif.mon_cb.perf_tbranch_o;
            tx.dbg_wb_cs = vif.mon_cb.dbg_wb_cs;
            tx.dbg_halt_id = vif.mon_cb.dbg_halt_id;
            if (tx.instr_valid_i)
                tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
