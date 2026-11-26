class Controller_Monitor;
    virtual Controller_interface vif;
    mailbox #(Controller_Transaction) mon2scb;
    mailbox #(Controller_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Controller_interface vif,
            mailbox #(Controller_Transaction) mon2scb, 
            mailbox #(Controller_Transaction) mon2cov, 
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Controller_Transaction tx;
        wait(vif.rst_n===1'b1);
        forever begin
            @(vif.mon_cb);
            tx = new();
            
            tx.ctrl_ack_i = vif.mon_cb.ctrl_ack_i;
            tx.ctrl_kill_i = vif.mon_cb.ctrl_kill_i;
            tx.irq_i = vif.mon_cb.irq_i;
            tx.irq_id_i = vif.mon_cb.irq_id_i;
            tx.m_IE_i = vif.mon_cb.m_IE_i;
            tx.irq_req_ctrl_o = vif.mon_cb.irq_req_ctrl_o;
            tx.irq_id_ctrl_o = vif.mon_cb.irq_id_ctrl_o;
            tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask
    
endclass


