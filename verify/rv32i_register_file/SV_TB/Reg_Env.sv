class Reg_Env #(parameter RV32E = 0, parameter DATA_WIDTH = 32);
    typedef Reg_Transaction #(RV32E, DATA_WIDTH) tx_t;
    Reg_Generator  #(RV32E, DATA_WIDTH) gen;
    Reg_driver     #(RV32E, DATA_WIDTH) drv;
    Reg_monitor    #(RV32E, DATA_WIDTH) mon;
    Reg_Scoreboard #(RV32E, DATA_WIDTH) scb;
    Reg_Coverage   #(RV32E, DATA_WIDTH) cov;

    mailbox #(tx_t) gen2drv;
    mailbox #(tx_t) mon2scb;
    mailbox #(tx_t) mon2cov;

    virtual Reg_interface #(DATA_WIDTH) vif;
    int num_tx;
    string test_type;

    function new(virtual Reg_interface #(DATA_WIDTH) vif, int num_tx=1000, string test_type="all");
        this.vif=vif;
        this.num_tx=num_tx;
        this.test_type=test_type;
    endfunction

    task build();
        gen2drv=new();
        mon2cov=new();
        mon2scb=new();

        gen = new(gen2drv, num_tx, test_type);
        drv = new(gen2drv, vif);
        mon = new(vif, mon2scb, mon2cov);
        scb = new(mon2scb);
        cov = new(mon2cov);
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
