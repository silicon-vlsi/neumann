class Fifo_Env;
    Fifo_Generator gen;
    Fifo_Driver drv;
    Fifo_Monitor mon;
    Fifo_Scoreboard scb;
    Fifo_Coverage cov;

    mailbox #(Fifo_Transaction) gen2drv;
    mailbox #(Fifo_Transaction) mon2scb;
    mailbox #(Fifo_Transaction) mon2cov;

    virtual Fifo_interface vif;
    int num_tx;

    function new(virtual Fifo_interface vif, int num_tx=1000);
        this.vif=vif;
        this.num_tx=num_tx;
    endfunction

    task build();
        gen2drv=new();
        mon2cov=new();
        mon2scb=new();

        gen = new(.gen2drv(gen2drv), .num_tx(num_tx));
        drv = new(.vif(vif), .gen2drv(gen2drv));
        mon = new(.vif(vif), .mon2scb(mon2scb), .mon2cov(mon2cov), .mon_count(0));
        scb = new(.mon2scb(mon2scb));
        cov = new(.mon2cov(mon2cov));
    endtask

    task reset();
        drv.reset();
    endtask

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
            cov.run();
        join_none
    endtask

    task post_test();
        wait (gen.done);
        wait (drv.drv_count == gen.gen_count);
        drv.idle();
        repeat (5) @(posedge vif.clk);
        while (mon2scb.num() != 0 || mon2cov.num() != 0)
            @(posedge vif.clk);
    endtask

    task report();
        $display("[ENV] gen=%0d drv=%0d mon=%0d scb=%0d",
                 gen.gen_count, drv.drv_count, mon.mon_count, scb.total_count);
        scb.report();
        cov.report();
    endtask

    task run();
        build();
        reset();
        test();
        post_test();
        report();
        $finish;
    endtask
endclass
