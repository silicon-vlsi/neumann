class Fifo_Driver;
    mailbox #(Fifo_Transaction) gen2drv;
    virtual Fifo_interface vif;
    int drv_count = 0;
    bit init_done = 0;
    logic [31:0] next_addr;
    bit   ready_seen;

    function new(mailbox #(Fifo_Transaction) gen2drv, virtual Fifo_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
        next_addr    = 32'h0000_1000;
        ready_seen   = 0;
    endfunction

    task automatic reset();
        vif.drv_cb.rst_n       <= 0;
        vif.drv_cb.clear_i     <= 0;
        vif.drv_cb.in_valid_i  <= 0;
        vif.drv_cb.in_addr_i   <= 0;
        vif.drv_cb.in_rdata_i  <= 0;
        vif.drv_cb.out_ready_i <= 0;
        repeat (3) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;
        @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] reset done");
    endtask

    task sample_ready();
        forever begin
            @(vif.mon_cb);
            ready_seen = (vif.mon_cb.in_ready_o === 1'b1);
        end
    endtask

    task automatic drive(Fifo_Transaction tx);
        logic do_push;
        if (tx.clear_i) begin
            vif.drv_cb.clear_i     <= 1;
            vif.drv_cb.in_valid_i  <= 0;
            vif.drv_cb.out_ready_i <= 0;
            next_addr = {tx.target[31:1], 1'b0};
            return;
        end
        do_push = tx.push && ready_seen;
        vif.drv_cb.clear_i     <= 0;
        vif.drv_cb.out_ready_i <= tx.out_ready_i;
        vif.drv_cb.in_valid_i  <= do_push;
        vif.drv_cb.in_addr_i   <= next_addr;
        vif.drv_cb.in_rdata_i  <= Fifo_Transaction::mem_word(next_addr);
        if (do_push)
            next_addr = {next_addr[31:2], 2'b00} + 32'h4;
    endtask

    task automatic idle();
        @(vif.drv_cb);
        vif.drv_cb.in_valid_i  <= 0;
        vif.drv_cb.out_ready_i <= 0;
        vif.drv_cb.clear_i     <= 0;
    endtask

    task run();
        Fifo_Transaction tx;
        wait (init_done);
        fork
            sample_ready();
        join_none
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            drv_count++;
        end
    endtask
endclass
