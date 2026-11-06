
class environment;

    generator    gen;
    driver       drv;
    mem_slave    mem;
    monitor      mon;
    scoreboard   scb;
    coverage_inf cov;

    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2scb;
    mailbox #(transaction) mon2cov;

    event gen_done;
    virtual lsu_if vif;

    function new(virtual lsu_if vif);
        this.vif = vif;

        gen2drv = new();
        mon2scb = new();
        mon2cov = new();

        gen = new(gen2drv, gen_done);
        drv = new(vif, gen2drv);
        mem = new(vif);
        mon = new(vif, mon2scb, mon2cov);
        scb = new(mon2scb);
        cov = new(mon2cov, vif);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mem.run();
            mon.run();
            scb.run();
            cov.run();
        join_none

        @(gen_done);
        repeat (200) @(posedge vif.clk);

        scb.report();
        cov.report();
    endtask

endclass
