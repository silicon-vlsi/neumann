class Cdec_Monitor;
    virtual Cdec_interface vif;
    mailbox #(Cdec_Transaction) mon2scb;
    mailbox #(Cdec_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Cdec_interface vif,
            mailbox #(Cdec_Transaction) mon2scb,
            mailbox #(Cdec_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Cdec_Transaction tx;
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.valid !== 1'b1)
                continue;
            tx = new();
            tx.instr_i         = vif.mon_cb.instr_i;
            tx.instr_o         = vif.mon_cb.instr_o;
            tx.is_compressed_o = vif.mon_cb.is_compressed_o;
            tx.illegal_instr_o = vif.mon_cb.illegal_instr_o;
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
