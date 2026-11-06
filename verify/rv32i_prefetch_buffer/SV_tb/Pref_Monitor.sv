class Pref_Monitor;
    virtual Pref_interface vif;
    mailbox #(Pref_Transaction) mon2scb;
    mailbox #(Pref_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Pref_interface vif,
            mailbox #(Pref_Transaction) mon2scb,
            mailbox #(Pref_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Pref_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.rst_n          = vif.mon_cb.rst_n;
            tx.req_i          = vif.mon_cb.req_i;
            tx.branch_i       = vif.mon_cb.branch_i;
            tx.addr_i         = vif.mon_cb.addr_i;
            tx.ready_i        = vif.mon_cb.ready_i;
            tx.instr_gnt_i    = vif.mon_cb.instr_gnt_i;
            tx.instr_rdata_i  = vif.mon_cb.instr_rdata_i;
            tx.instr_rvalid_i = vif.mon_cb.instr_rvalid_i;
            tx.valid_o        = vif.mon_cb.valid_o;
            tx.rdata_o        = vif.mon_cb.rdata_o;
            tx.addr_o         = vif.mon_cb.addr_o;
            tx.instr_req_o    = vif.mon_cb.instr_req_o;
            tx.instr_addr_o   = vif.mon_cb.instr_addr_o;
            tx.busy_o         = vif.mon_cb.busy_o;
            if (tx.branch_i || (tx.valid_o && tx.ready_i))
                tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
