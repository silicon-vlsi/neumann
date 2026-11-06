class Cdec_Driver;
    mailbox #(Cdec_Transaction) gen2drv;
    virtual Cdec_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    function new(mailbox #(Cdec_Transaction) gen2drv, virtual Cdec_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    task automatic reset();
        vif.drv_cb.valid   <= 0;
        vif.drv_cb.instr_i <= 32'h0000_0013;
        repeat (2) @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] init done");
    endtask

    task automatic drive(Cdec_Transaction tx);
        vif.drv_cb.valid   <= 1;
        vif.drv_cb.instr_i <= tx.instr_i;
    endtask

    task automatic idle();
        @(vif.drv_cb);
        vif.drv_cb.valid <= 0;
    endtask

    task run();
        Cdec_Transaction tx;
        wait (init_done);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            drv_count++;
        end
    endtask
endclass
