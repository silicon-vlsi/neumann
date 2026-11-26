class Decoder_Monitor;
    virtual Decoder_interface vif;
    mailbox #(Decoder_Transaction) mon2scb;
    mailbox #(Decoder_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Decoder_interface vif,
            mailbox #(Decoder_Transaction) mon2scb,
            mailbox #(Decoder_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Decoder_Transaction tx;
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.valid !== 1'b1)
                continue;
            tx = new();
            tx.deassert_we_i         = vif.mon_cb.deassert_we_i;
            tx.data_misaligned_i     = vif.mon_cb.data_misaligned_i;
            tx.branch_mux_i          = vif.mon_cb.branch_mux_i;
            tx.jump_mux_i            = vif.mon_cb.jump_mux_i;
            tx.instr_rdata_i         = vif.mon_cb.instr_rdata_i;
            tx.illegal_c_insn_i      = vif.mon_cb.illegal_c_insn_i;
            tx.illegal_insn_o        = vif.mon_cb.illegal_insn_o;
            tx.ebrk_insn_o           = vif.mon_cb.ebrk_insn_o;
            tx.mret_insn_o           = vif.mon_cb.mret_insn_o;
            tx.ecall_insn_o          = vif.mon_cb.ecall_insn_o;
            tx.pipe_flush_o          = vif.mon_cb.pipe_flush_o;
            tx.alu_operator_o        = vif.mon_cb.alu_operator_o;
            tx.alu_op_a_mux_sel_o    = vif.mon_cb.alu_op_a_mux_sel_o;
            tx.alu_op_b_mux_sel_o    = vif.mon_cb.alu_op_b_mux_sel_o;
            tx.imm_a_mux_sel_o       = vif.mon_cb.imm_a_mux_sel_o;
            tx.imm_b_mux_sel_o       = vif.mon_cb.imm_b_mux_sel_o;
            tx.regfile_we_o          = vif.mon_cb.regfile_we_o;
            tx.csr_access_o          = vif.mon_cb.csr_access_o;
            tx.csr_op_o              = vif.mon_cb.csr_op_o;
            tx.csr_status_o          = vif.mon_cb.csr_status_o;
            tx.data_req_o            = vif.mon_cb.data_req_o;
            tx.data_we_o             = vif.mon_cb.data_we_o;
            tx.data_type_o           = vif.mon_cb.data_type_o;
            tx.data_sign_extension_o = vif.mon_cb.data_sign_extension_o;
            tx.data_reg_offset_o     = vif.mon_cb.data_reg_offset_o;
            tx.data_load_event_o     = vif.mon_cb.data_load_event_o;
            tx.jump_in_id_o          = vif.mon_cb.jump_in_id_o;
            tx.branch_in_id_o        = vif.mon_cb.branch_in_id_o;
            tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
