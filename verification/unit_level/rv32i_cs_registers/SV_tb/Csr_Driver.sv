class Csr_Driver;
    mailbox #(Csr_Transaction) gen2drv;
    virtual Csr_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    function new(mailbox #(Csr_Transaction) gen2drv, virtual Csr_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    task automatic reset();
        vif.drv_cb.rst_n              <= 0;
        vif.drv_cb.core_id_i          <= 4'h5;
        vif.drv_cb.cluster_id_i       <= 6'h2A;
        vif.drv_cb.boot_addr_i        <= 24'h00_1C00;
        vif.drv_cb.csr_access_i       <= 0;
        vif.drv_cb.csr_addr_i         <= 0;
        vif.drv_cb.csr_wdata_i        <= 0;
        vif.drv_cb.csr_op_i           <= 0;
        vif.drv_cb.pc_if_i            <= 0;
        vif.drv_cb.pc_id_i            <= 0;
        vif.drv_cb.csr_save_if_i      <= 0;
        vif.drv_cb.csr_save_id_i      <= 0;
        vif.drv_cb.csr_restore_mret_i <= 0;
        vif.drv_cb.csr_cause_i        <= 0;
        vif.drv_cb.csr_save_cause_i   <= 0;
        vif.drv_cb.if_valid_i         <= 0;
        vif.drv_cb.id_valid_i         <= 0;
        vif.drv_cb.is_compressed_i    <= 0;
        vif.drv_cb.is_decoding_i      <= 0;
        vif.drv_cb.imiss_i            <= 0;
        vif.drv_cb.pc_set_i           <= 0;
        vif.drv_cb.jump_i             <= 0;
        vif.drv_cb.branch_i           <= 0;
        vif.drv_cb.branch_taken_i     <= 0;
        vif.drv_cb.mem_load_i         <= 0;
        vif.drv_cb.mem_store_i        <= 0;
        repeat (3) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;
        @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] reset done");
    endtask

    task automatic drive(Csr_Transaction tx);
        vif.drv_cb.csr_access_i       <= tx.csr_access_i;
        vif.drv_cb.csr_addr_i         <= tx.csr_addr_i;
        vif.drv_cb.csr_wdata_i        <= tx.csr_wdata_i;
        vif.drv_cb.csr_op_i           <= tx.csr_op_i;
        vif.drv_cb.pc_if_i            <= tx.pc_if_i;
        vif.drv_cb.pc_id_i            <= tx.pc_id_i;
        vif.drv_cb.csr_save_if_i      <= tx.csr_save_if_i;
        vif.drv_cb.csr_save_id_i      <= tx.csr_save_id_i;
        vif.drv_cb.csr_restore_mret_i <= tx.csr_restore_mret_i;
        vif.drv_cb.csr_cause_i        <= tx.csr_cause_i;
        vif.drv_cb.csr_save_cause_i   <= tx.csr_save_cause_i;
        vif.drv_cb.if_valid_i         <= tx.if_valid_i;
        vif.drv_cb.id_valid_i         <= tx.id_valid_i;
        vif.drv_cb.is_compressed_i    <= tx.is_compressed_i;
        vif.drv_cb.is_decoding_i      <= tx.is_decoding_i;
        vif.drv_cb.imiss_i            <= tx.imiss_i;
        vif.drv_cb.pc_set_i           <= tx.pc_set_i;
        vif.drv_cb.jump_i             <= tx.jump_i;
        vif.drv_cb.branch_i           <= tx.branch_i;
        vif.drv_cb.branch_taken_i     <= tx.branch_taken_i;
        vif.drv_cb.mem_load_i         <= tx.mem_load_i;
        vif.drv_cb.mem_store_i        <= tx.mem_store_i;
    endtask

    task automatic idle();
        @(vif.drv_cb);
        vif.drv_cb.csr_access_i       <= 0;
        vif.drv_cb.csr_op_i           <= 0;
        vif.drv_cb.csr_save_cause_i   <= 0;
        vif.drv_cb.csr_restore_mret_i <= 0;
    endtask

    task run();
        Csr_Transaction tx;
        wait (init_done);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            drv_count++;
        end
    endtask
endclass
