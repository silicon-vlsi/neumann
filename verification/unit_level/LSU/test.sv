class test;

    environment env;
    virtual lsu_if vif;
    int num_rand;
    int gnt_delay;
    int rvalid_delay;

    function new(virtual lsu_if vif, int num_rand,
                 int gnt_delay = 0, int rvalid_delay = 1);
        this.vif          = vif;
        this.num_rand     = num_rand;
        this.gnt_delay    = gnt_delay;
        this.rvalid_delay = rvalid_delay;
        env = new(vif);
    endfunction

    function void configure();
        env.gen.num_rand     = num_rand;
        env.mem.gnt_delay    = gnt_delay;
        env.mem.rvalid_delay = rvalid_delay;
    endfunction

    task run();
        configure();
        env.run();
    endtask

endclass
