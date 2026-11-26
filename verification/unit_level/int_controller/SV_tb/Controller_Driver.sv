class Controller_Driver;
    mailbox #(Controller_Transaction) gen2drv;
    virtual Controller_interface vif;
    int drv_count = 0;

    function new(mailbox #(Controller_Transaction) gen2drv,virtual Controller_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    task automatic reset();
        vif.rst_n           <= 1'b0;
        vif.drv_cb.ctrl_ack_i  <= 0;
        vif.drv_cb.ctrl_kill_i <= 0;
        vif.drv_cb.irq_i       <= 0;
        vif.drv_cb.irq_id_i    <= 0;
        vif.drv_cb.m_IE_i      <= 0;
        repeat (2) @(vif.drv_cb);
        vif.rst_n           <= 1'b1;
        @(vif.drv_cb);
        $display("[DRV] reset done");
    endtask

    task automatic drive(Controller_Transaction tx);
        vif.drv_cb.ctrl_ack_i  <= tx.ctrl_ack_i;
        vif.drv_cb.ctrl_kill_i <= tx.ctrl_kill_i;
        vif.drv_cb.irq_i       <= tx.irq_i;
        vif.drv_cb.irq_id_i    <= tx.irq_id_i;
        vif.drv_cb.m_IE_i      <= tx.m_IE_i;
    endtask

    task run();
        Controller_Transaction tx;
        wait (vif.rst_n === 1'b1);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            tx.display("DRV");
            drv_count++;
        end
    endtask
endclass