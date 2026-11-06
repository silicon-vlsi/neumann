class Dbg_Driver;
    mailbox #(Dbg_Transaction) gen2drv;
    virtual Dbg_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    bit          pending;
    logic [14:0] p_addr;
    logic        p_we;
    logic [31:0] p_wdata;
    int          bus_ops = 0;

    function new(mailbox #(Dbg_Transaction) gen2drv, virtual Dbg_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
        pending      = 0;
    endfunction

    task automatic reset();
        vif.drv_cb.rst_n <= 0;
        vif.drv_cb.debug_req_i <= 0;
        vif.drv_cb.debug_addr_i <= 0;
        vif.drv_cb.debug_we_i <= 0;
        vif.drv_cb.debug_wdata_i <= 0;
        vif.drv_cb.debug_halt_i <= 0;
        vif.drv_cb.debug_resume_i <= 0;
        vif.drv_cb.trap_i <= 0;
        vif.drv_cb.exc_cause_i <= 0;
        vif.drv_cb.dbg_ack_i <= 0;
        vif.drv_cb.regfile_rdata_i <= 0;
        vif.drv_cb.csr_rdata_i <= 0;
        vif.drv_cb.pc_if_i <= 0;
        vif.drv_cb.pc_id_i <= 0;
        vif.drv_cb.instr_valid_id_i <= 0;
        vif.drv_cb.sleeping_i <= 0;
        repeat (3) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;
        @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] reset done");
    endtask

    task drive(Dbg_Transaction tx);
        if (!pending && tx.bus_start) begin
            pending = 1;
            p_addr  = tx.bus_addr;
            p_we    = tx.bus_we;
            p_wdata = tx.bus_wdata;
            bus_ops++;
        end
        vif.drv_cb.debug_req_i   <= pending;
        vif.drv_cb.debug_addr_i  <= pending ? p_addr  : tx.bus_addr;
        vif.drv_cb.debug_we_i    <= pending ? p_we    : 1'b0;
        vif.drv_cb.debug_wdata_i <= pending ? p_wdata : tx.bus_wdata;
        vif.drv_cb.debug_halt_i <= tx.debug_halt_i;
        vif.drv_cb.debug_resume_i <= tx.debug_resume_i;
        vif.drv_cb.trap_i <= tx.trap_i;
        vif.drv_cb.exc_cause_i <= tx.exc_cause_i;
        vif.drv_cb.dbg_ack_i <= tx.dbg_ack_i;
        vif.drv_cb.regfile_rdata_i <= tx.regfile_rdata_i;
        vif.drv_cb.csr_rdata_i <= tx.csr_rdata_i;
        vif.drv_cb.pc_if_i <= tx.pc_if_i;
        vif.drv_cb.pc_id_i <= tx.pc_id_i;
        vif.drv_cb.instr_valid_id_i <= tx.instr_valid_id_i;
        vif.drv_cb.sleeping_i <= tx.sleeping_i;
    endtask

    task observe_gnt();
        @(vif.mon_cb);
        if (vif.mon_cb.debug_req_i === 1'b1 && vif.mon_cb.debug_gnt_o === 1'b1)
            pending = 0;
    endtask

    task automatic idle();
        repeat (4) begin
            @(vif.drv_cb);
            vif.drv_cb.debug_req_i <= 0;
            observe_gnt();
        end
    endtask

    task run();
        Dbg_Transaction tx;
        wait (init_done);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            drv_count++;
            observe_gnt();
        end
    endtask
endclass
