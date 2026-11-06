class If_Monitor;
    virtual If_interface vif;
    mailbox #(If_Transaction) mon2scb;
    mailbox #(If_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual If_interface vif,
            mailbox #(If_Transaction) mon2scb,
            mailbox #(If_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        If_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.rst_n = vif.mon_cb.rst_n;
            tx.boot_addr_i = vif.mon_cb.boot_addr_i;
            tx.req_i = vif.mon_cb.req_i;
            tx.instr_gnt_i = vif.mon_cb.instr_gnt_i;
            tx.instr_rvalid_i = vif.mon_cb.instr_rvalid_i;
            tx.instr_rdata_i = vif.mon_cb.instr_rdata_i;
            tx.clear_instr_valid_i = vif.mon_cb.clear_instr_valid_i;
            tx.pc_set_i = vif.mon_cb.pc_set_i;
            tx.exception_pc_reg_i = vif.mon_cb.exception_pc_reg_i;
            tx.pc_mux_i = vif.mon_cb.pc_mux_i;
            tx.exc_pc_mux_i = vif.mon_cb.exc_pc_mux_i;
            tx.exc_vec_pc_mux_i = vif.mon_cb.exc_vec_pc_mux_i;
            tx.jump_target_ex_i = vif.mon_cb.jump_target_ex_i;
            tx.dbg_jump_addr_i = vif.mon_cb.dbg_jump_addr_i;
            tx.halt_if_i = vif.mon_cb.halt_if_i;
            tx.id_ready_i = vif.mon_cb.id_ready_i;
            tx.instr_req_o = vif.mon_cb.instr_req_o;
            tx.instr_addr_o = vif.mon_cb.instr_addr_o;
            tx.instr_valid_id_o = vif.mon_cb.instr_valid_id_o;
            tx.instr_rdata_id_o = vif.mon_cb.instr_rdata_id_o;
            tx.is_compressed_id_o = vif.mon_cb.is_compressed_id_o;
            tx.illegal_c_insn_id_o = vif.mon_cb.illegal_c_insn_id_o;
            tx.pc_if_o = vif.mon_cb.pc_if_o;
            tx.pc_id_o = vif.mon_cb.pc_id_o;
            tx.if_valid_o = vif.mon_cb.if_valid_o;
            tx.if_busy_o = vif.mon_cb.if_busy_o;
            tx.perf_imiss_o = vif.mon_cb.perf_imiss_o;
            if (tx.pc_set_i || tx.if_valid_o)
                tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
