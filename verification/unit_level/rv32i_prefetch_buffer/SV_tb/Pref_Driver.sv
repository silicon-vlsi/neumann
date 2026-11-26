class Pref_Driver;
    mailbox #(Pref_Transaction) gen2drv;
    virtual Pref_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    logic [31:0] pend_addr[$];
    int          pend_wait[$];
    int unsigned next_lat;
    int          grants = 0;
    logic        mem_rv;
    logic [31:0] mem_rd;
    int          responses = 0;

    function new(mailbox #(Pref_Transaction) gen2drv, virtual Pref_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
        next_lat     = 0;
    endfunction

    task automatic reset();
        vif.drv_cb.rst_n          <= 0;
        vif.drv_cb.req_i          <= 0;
        vif.drv_cb.branch_i       <= 0;
        vif.drv_cb.addr_i         <= 0;
        vif.drv_cb.ready_i        <= 0;
        vif.drv_cb.instr_gnt_i    <= 0;
        vif.drv_cb.instr_rvalid_i <= 0;
        vif.drv_cb.instr_rdata_i  <= 0;
        repeat (3) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;
        @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] reset done");
    endtask

    task observe_grant();
        @(vif.mon_cb);
        if (vif.mon_cb.instr_req_o === 1'b1 && vif.mon_cb.instr_gnt_i === 1'b1) begin
            pend_addr.push_back(vif.mon_cb.instr_addr_o);
            pend_wait.push_back(next_lat);
            grants++;
        end
    endtask

    task drive_mem(Pref_Transaction tx);
        mem_rv = 0;
        mem_rd = $urandom();
        if (pend_addr.size() > 0) begin
            if (pend_wait[0] == 0) begin
                mem_rv = 1;
                mem_rd = Pref_Transaction::mem_word(pend_addr[0]);
                void'(pend_addr.pop_front());
                void'(pend_wait.pop_front());
                responses++;
            end else
                pend_wait[0] = pend_wait[0] - 1;
        end
        vif.drv_cb.instr_gnt_i    <= tx.instr_gnt_i;
        vif.drv_cb.instr_rvalid_i <= mem_rv;
        vif.drv_cb.instr_rdata_i  <= mem_rd;
        next_lat = tx.lat;
    endtask

    task automatic drive(Pref_Transaction tx);
        vif.drv_cb.req_i    <= tx.req_i;
        vif.drv_cb.branch_i <= tx.branch_i;
        vif.drv_cb.addr_i   <= tx.addr_i;
        vif.drv_cb.ready_i  <= tx.ready_i;
        drive_mem(tx);
    endtask

    task automatic idle();
        Pref_Transaction tx;
        tx = new();
        tx.req_i = 0;
        tx.branch_i = 0;
        tx.addr_i = 0;
        tx.ready_i = 0;
        tx.instr_gnt_i = 0;
        tx.lat = 0;
        repeat (8) begin
            @(vif.drv_cb);
            drive(tx);
            observe_grant();
        end
    endtask

    task run();
        Pref_Transaction tx;
        wait (init_done);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            drv_count++;
            observe_grant();
        end
    endtask
endclass
