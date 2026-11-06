class Fifo_Monitor;
    virtual Fifo_interface vif;
    mailbox #(Fifo_Transaction) mon2scb;
    mailbox #(Fifo_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Fifo_interface vif,
            mailbox #(Fifo_Transaction) mon2scb,
            mailbox #(Fifo_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Fifo_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.rst_n              = vif.mon_cb.rst_n;
            tx.clear_i            = vif.mon_cb.clear_i;
            tx.in_addr_i          = vif.mon_cb.in_addr_i;
            tx.in_rdata_i         = vif.mon_cb.in_rdata_i;
            tx.in_valid_i         = vif.mon_cb.in_valid_i;
            tx.out_ready_i        = vif.mon_cb.out_ready_i;
            tx.in_ready_o         = vif.mon_cb.in_ready_o;
            tx.out_valid_o        = vif.mon_cb.out_valid_o;
            tx.out_rdata_o        = vif.mon_cb.out_rdata_o;
            tx.out_addr_o         = vif.mon_cb.out_addr_o;
            tx.out_valid_stored_o = vif.mon_cb.out_valid_stored_o;
            if (tx.in_valid_i || tx.out_valid_o || tx.clear_i)
                tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
