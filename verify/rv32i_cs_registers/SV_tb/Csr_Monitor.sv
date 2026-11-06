class Csr_Monitor;
    virtual Csr_interface vif;
    mailbox #(Csr_Transaction) mon2scb;
    mailbox #(Csr_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Csr_interface vif,
            mailbox #(Csr_Transaction) mon2scb,
            mailbox #(Csr_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Csr_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.rst_n              = vif.mon_cb.rst_n;
            tx.core_id_i          = vif.mon_cb.core_id_i;
            tx.cluster_id_i       = vif.mon_cb.cluster_id_i;
            tx.boot_addr_i        = vif.mon_cb.boot_addr_i;
            tx.csr_access_i       = vif.mon_cb.csr_access_i;
            tx.csr_addr_i         = vif.mon_cb.csr_addr_i;
            tx.csr_wdata_i        = vif.mon_cb.csr_wdata_i;
            tx.csr_op_i           = vif.mon_cb.csr_op_i;
            tx.pc_if_i            = vif.mon_cb.pc_if_i;
            tx.pc_id_i            = vif.mon_cb.pc_id_i;
            tx.csr_save_if_i      = vif.mon_cb.csr_save_if_i;
            tx.csr_save_id_i      = vif.mon_cb.csr_save_id_i;
            tx.csr_restore_mret_i = vif.mon_cb.csr_restore_mret_i;
            tx.csr_cause_i        = vif.mon_cb.csr_cause_i;
            tx.csr_save_cause_i   = vif.mon_cb.csr_save_cause_i;
            tx.if_valid_i         = vif.mon_cb.if_valid_i;
            tx.id_valid_i         = vif.mon_cb.id_valid_i;
            tx.is_compressed_i    = vif.mon_cb.is_compressed_i;
            tx.is_decoding_i      = vif.mon_cb.is_decoding_i;
            tx.imiss_i            = vif.mon_cb.imiss_i;
            tx.pc_set_i           = vif.mon_cb.pc_set_i;
            tx.jump_i             = vif.mon_cb.jump_i;
            tx.branch_i           = vif.mon_cb.branch_i;
            tx.branch_taken_i     = vif.mon_cb.branch_taken_i;
            tx.mem_load_i         = vif.mon_cb.mem_load_i;
            tx.mem_store_i        = vif.mon_cb.mem_store_i;
            tx.csr_rdata_o        = vif.mon_cb.csr_rdata_o;
            tx.m_irq_enable_o     = vif.mon_cb.m_irq_enable_o;
            tx.mepc_o             = vif.mon_cb.mepc_o;
            if (tx.csr_access_i || tx.csr_save_cause_i || tx.csr_restore_mret_i)
                tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
