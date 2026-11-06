class Reg_monitor #(parameter RV32E = 0, parameter DATA_WIDTH = 32);
    typedef Reg_Transaction #(RV32E, DATA_WIDTH) tx_t;
    virtual Reg_interface #(DATA_WIDTH).MON vif;
    mailbox #(tx_t) mon2scb;
    mailbox #(tx_t) mon2cov;
    int mon_count=0;

    function new(virtual Reg_interface #(DATA_WIDTH).MON vif, mailbox #(tx_t) mon2scb, mailbox #(tx_t) mon2cov);
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
    endfunction

    task run();
        tx_t tx;
        forever begin
            @(vif.mon_cb);
            tx=new();
            tx.rst_n     = vif.mon_cb.rst_n;
            tx.test_en_i = vif.mon_cb.test_en_i;
            tx.raddr_a_i = vif.mon_cb.raddr_a_i;
            tx.raddr_b_i = vif.mon_cb.raddr_b_i;
            tx.waddr_a_i = vif.mon_cb.waddr_a_i;
            tx.wdata_a_i = vif.mon_cb.wdata_a_i;
            tx.we_a_i    = vif.mon_cb.we_a_i;
            tx.rdata_a_o = vif.mon_cb.rdata_a_o;
            tx.rdata_b_o = vif.mon_cb.rdata_b_o;
            tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask
endclass
