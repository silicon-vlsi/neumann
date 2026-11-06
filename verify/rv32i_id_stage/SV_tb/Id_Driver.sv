class Id_Driver;
    mailbox #(Id_Transaction) gen2drv;
    virtual Id_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    logic        cur_valid;
    logic [31:0] cur_instr;
    logic [31:0] cur_pc;
    logic [31:0] pc;
    int          loads = 0;

    function new(mailbox #(Id_Transaction) gen2drv, virtual Id_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
        cur_valid    = 0;
        cur_instr    = 32'h0000_0013;
        cur_pc       = 32'h0000_0080;
        pc           = 32'h0000_0080;
    endfunction

    task automatic reset();
        vif.drv_cb.rst_n <= 0;
        vif.drv_cb.test_en_i <= 0;
        vif.drv_cb.fetch_enable_i <= 0;
        vif.drv_cb.instr_valid_i <= 0;
        vif.drv_cb.instr_rdata_i <= 0;
        vif.drv_cb.branch_decision_i <= 0;
        vif.drv_cb.illegal_c_insn_i <= 0;
        vif.drv_cb.is_compressed_i <= 0;
        vif.drv_cb.pc_id_i <= 0;
        vif.drv_cb.ex_ready_i <= 0;
        vif.drv_cb.data_misaligned_i <= 0;
        vif.drv_cb.misaligned_addr_i <= 0;
        vif.drv_cb.irq_i <= 0;
        vif.drv_cb.irq_id_i <= 0;
        vif.drv_cb.m_irq_enable_i <= 0;
        vif.drv_cb.lsu_load_err_i <= 0;
        vif.drv_cb.lsu_store_err_i <= 0;
        vif.drv_cb.dbg_settings_i <= 0;
        vif.drv_cb.dbg_req_i <= 0;
        vif.drv_cb.dbg_stall_i <= 0;
        vif.drv_cb.dbg_reg_rreq_i <= 0;
        vif.drv_cb.dbg_reg_raddr_i <= 0;
        vif.drv_cb.dbg_reg_wreq_i <= 0;
        vif.drv_cb.dbg_reg_waddr_i <= 0;
        vif.drv_cb.dbg_reg_wdata_i <= 0;
        vif.drv_cb.dbg_jump_req_i <= 0;
        vif.drv_cb.regfile_wdata_lsu_i <= 0;
        vif.drv_cb.regfile_wdata_ex_i <= 0;
        vif.drv_cb.csr_rdata_i <= 0;
        vif.drv_cb.fetch_enable_i <= 1;
        vif.drv_cb.instr_rdata_i <= 32'h0000_0013;
        repeat (3) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;
        init_done = 1;
        $display("[DRV] reset done");
    endtask

    task drive(Id_Transaction tx);
        vif.drv_cb.fetch_enable_i      <= 1;
        vif.drv_cb.instr_valid_i       <= cur_valid;
        vif.drv_cb.instr_rdata_i       <= cur_instr;
        vif.drv_cb.pc_id_i             <= cur_pc;
        vif.drv_cb.is_compressed_i     <= 0;
        vif.drv_cb.illegal_c_insn_i    <= 0;
        vif.drv_cb.branch_decision_i   <= tx.branch_decision_i;
        vif.drv_cb.ex_ready_i          <= tx.ex_ready_i;
        vif.drv_cb.data_misaligned_i   <= tx.data_misaligned_i;
        vif.drv_cb.misaligned_addr_i   <= tx.misaligned_addr_i;
        vif.drv_cb.dbg_reg_rreq_i      <= tx.dbg_reg_rreq_i;
        vif.drv_cb.dbg_reg_raddr_i     <= tx.dbg_reg_raddr_i;
        vif.drv_cb.dbg_reg_wreq_i      <= tx.dbg_reg_wreq_i;
        vif.drv_cb.dbg_reg_waddr_i     <= tx.dbg_reg_waddr_i;
        vif.drv_cb.dbg_reg_wdata_i     <= tx.dbg_reg_wdata_i;
        vif.drv_cb.regfile_wdata_lsu_i <= tx.regfile_wdata_lsu_i;
        vif.drv_cb.regfile_wdata_ex_i  <= tx.regfile_wdata_ex_i;
        vif.drv_cb.csr_rdata_i         <= tx.csr_rdata_i;
    endtask

    task fetch_update(Id_Transaction tx);
        @(vif.mon_cb);
        if (vif.mon_cb.pc_set_o === 1'b1) begin
            cur_valid = 0;
            pc        = {$urandom_range(0, 32'h3FFF_FFFF), 2'b00};
        end else if (vif.mon_cb.halt_if_o === 1'b0 && vif.mon_cb.id_ready_o === 1'b1) begin
            cur_valid = tx.fetch_valid;
            if (tx.fetch_valid) begin
                cur_instr = tx.next_instr;
                cur_pc    = pc;
                pc        = pc + 32'h4;
                loads++;
            end
        end else if (vif.mon_cb.clear_instr_valid_o === 1'b1)
            cur_valid = 0;
    endtask

    task automatic idle();
        Id_Transaction tx;
        tx = new();
        tx.next_instr = 0;
        tx.fetch_valid = 0;
        tx.branch_decision_i = 0;
        tx.ex_ready_i = 0;
        tx.data_misaligned_i = 0;
        tx.misaligned_addr_i = 0;
        tx.dbg_reg_rreq_i = 0;
        tx.dbg_reg_raddr_i = 0;
        tx.dbg_reg_wreq_i = 0;
        tx.dbg_reg_waddr_i = 0;
        tx.dbg_reg_wdata_i = 0;
        tx.regfile_wdata_lsu_i = 0;
        tx.regfile_wdata_ex_i = 0;
        tx.csr_rdata_i = 0;
        tx.ex_ready_i = 1;
        repeat (6) begin
            @(vif.drv_cb);
            drive(tx);
            fetch_update(tx);
        end
    endtask

    task run();
        Id_Transaction tx;
        wait (init_done);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            drv_count++;
            fetch_update(tx);
        end
    endtask
endclass
