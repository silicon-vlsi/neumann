class If_Driver;
    mailbox #(If_Transaction) gen2drv;
    virtual If_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    logic [31:0] boot_addr;
    logic [31:0] pend_addr[$];
    int          pend_wait[$];
    int unsigned next_lat;
    int          grants = 0;
    int          responses = 0;
    logic        mem_rv;
    logic [31:0] mem_rd;

    function new(mailbox #(If_Transaction) gen2drv, virtual If_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
        next_lat     = 0;
        boot_addr    = 32'h1C00_8000;
    endfunction

    task automatic reset();
        vif.drv_cb.rst_n <= 0;
        vif.drv_cb.boot_addr_i <= boot_addr;
        vif.drv_cb.instr_gnt_i <= 0;
        vif.drv_cb.instr_rvalid_i <= 0;
        vif.drv_cb.instr_rdata_i <= 0;
        vif.drv_cb.req_i <= 0;
        vif.drv_cb.clear_instr_valid_i <= 0;
        vif.drv_cb.pc_set_i <= 0;
        vif.drv_cb.exception_pc_reg_i <= 0;
        vif.drv_cb.pc_mux_i <= 0;
        vif.drv_cb.exc_pc_mux_i <= 0;
        vif.drv_cb.exc_vec_pc_mux_i <= 0;
        vif.drv_cb.jump_target_ex_i <= 0;
        vif.drv_cb.dbg_jump_addr_i <= 0;
        vif.drv_cb.halt_if_i <= 0;
        vif.drv_cb.id_ready_i <= 0;
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

    task drive_mem(If_Transaction tx);
        mem_rv = 0;
        mem_rd = $urandom();
        if (pend_addr.size() > 0) begin
            if (pend_wait[0] == 0) begin
                mem_rv = 1;
                mem_rd = If_Transaction::mem_word(pend_addr[0]);
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

    task drive(If_Transaction tx);
        vif.drv_cb.req_i <= tx.req_i;
        vif.drv_cb.clear_instr_valid_i <= tx.clear_instr_valid_i;
        vif.drv_cb.pc_set_i <= tx.pc_set_i;
        vif.drv_cb.exception_pc_reg_i <= tx.exception_pc_reg_i;
        vif.drv_cb.pc_mux_i <= tx.pc_mux_i;
        vif.drv_cb.exc_pc_mux_i <= tx.exc_pc_mux_i;
        vif.drv_cb.exc_vec_pc_mux_i <= tx.exc_vec_pc_mux_i;
        vif.drv_cb.jump_target_ex_i <= tx.jump_target_ex_i;
        vif.drv_cb.dbg_jump_addr_i <= tx.dbg_jump_addr_i;
        vif.drv_cb.halt_if_i <= tx.halt_if_i;
        vif.drv_cb.id_ready_i <= tx.id_ready_i;
        drive_mem(tx);
    endtask

    task automatic idle();
        If_Transaction tx;
        tx = new();
        tx.req_i = 0;
        tx.clear_instr_valid_i = 0;
        tx.pc_set_i = 0;
        tx.exception_pc_reg_i = 0;
        tx.pc_mux_i = 0;
        tx.exc_pc_mux_i = 0;
        tx.exc_vec_pc_mux_i = 0;
        tx.jump_target_ex_i = 0;
        tx.dbg_jump_addr_i = 0;
        tx.halt_if_i = 0;
        tx.id_ready_i = 0;
        tx.halt_if_i = 1;
        tx.instr_gnt_i = 1;
        tx.lat = 0;
        repeat (8) begin
            @(vif.drv_cb);
            drive(tx);
            observe_grant();
        end
    endtask

    task run();
        If_Transaction tx;
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
