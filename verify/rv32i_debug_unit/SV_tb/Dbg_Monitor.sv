class Dbg_Monitor;
    virtual Dbg_interface vif;
    mailbox #(Dbg_Transaction) mon2scb;
    mailbox #(Dbg_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Dbg_interface vif,
            mailbox #(Dbg_Transaction) mon2scb,
            mailbox #(Dbg_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Dbg_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.rst_n = vif.mon_cb.rst_n;
            tx.debug_req_i = vif.mon_cb.debug_req_i;
            tx.debug_addr_i = vif.mon_cb.debug_addr_i;
            tx.debug_we_i = vif.mon_cb.debug_we_i;
            tx.debug_wdata_i = vif.mon_cb.debug_wdata_i;
            tx.debug_halt_i = vif.mon_cb.debug_halt_i;
            tx.debug_resume_i = vif.mon_cb.debug_resume_i;
            tx.trap_i = vif.mon_cb.trap_i;
            tx.exc_cause_i = vif.mon_cb.exc_cause_i;
            tx.dbg_ack_i = vif.mon_cb.dbg_ack_i;
            tx.regfile_rdata_i = vif.mon_cb.regfile_rdata_i;
            tx.csr_rdata_i = vif.mon_cb.csr_rdata_i;
            tx.pc_if_i = vif.mon_cb.pc_if_i;
            tx.pc_id_i = vif.mon_cb.pc_id_i;
            tx.instr_valid_id_i = vif.mon_cb.instr_valid_id_i;
            tx.sleeping_i = vif.mon_cb.sleeping_i;
            tx.debug_gnt_o = vif.mon_cb.debug_gnt_o;
            tx.debug_rvalid_o = vif.mon_cb.debug_rvalid_o;
            tx.debug_rdata_o = vif.mon_cb.debug_rdata_o;
            tx.debug_halted_o = vif.mon_cb.debug_halted_o;
            tx.settings_o = vif.mon_cb.settings_o;
            tx.stall_o = vif.mon_cb.stall_o;
            tx.dbg_req_o = vif.mon_cb.dbg_req_o;
            tx.regfile_rreq_o = vif.mon_cb.regfile_rreq_o;
            tx.regfile_raddr_o = vif.mon_cb.regfile_raddr_o;
            tx.regfile_wreq_o = vif.mon_cb.regfile_wreq_o;
            tx.regfile_waddr_o = vif.mon_cb.regfile_waddr_o;
            tx.regfile_wdata_o = vif.mon_cb.regfile_wdata_o;
            tx.csr_req_o = vif.mon_cb.csr_req_o;
            tx.csr_addr_o = vif.mon_cb.csr_addr_o;
            tx.csr_we_o = vif.mon_cb.csr_we_o;
            tx.csr_wdata_o = vif.mon_cb.csr_wdata_o;
            tx.jump_req_o = vif.mon_cb.jump_req_o;
            tx.jump_addr_o = vif.mon_cb.jump_addr_o;
            if (tx.debug_req_i || tx.debug_rvalid_o)
                tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
