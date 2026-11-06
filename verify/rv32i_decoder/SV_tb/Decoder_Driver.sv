class Decoder_Driver;
    mailbox #(Decoder_Transaction) gen2drv;
    virtual Decoder_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    function new(mailbox #(Decoder_Transaction) gen2drv,virtual Decoder_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    task automatic reset();
        vif.drv_cb.valid             <= 0;
        vif.drv_cb.deassert_we_i     <= 0;
        vif.drv_cb.data_misaligned_i <= 0;
        vif.drv_cb.branch_mux_i      <= 0;
        vif.drv_cb.jump_mux_i        <= 0;
        vif.drv_cb.instr_rdata_i     <= 32'h0000_0013;
        vif.drv_cb.illegal_c_insn_i  <= 0;
        repeat (2) @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] init done");
    endtask

    task automatic drive(Decoder_Transaction tx);
        vif.drv_cb.valid             <= 1;
        vif.drv_cb.deassert_we_i     <= tx.deassert_we_i;
        vif.drv_cb.data_misaligned_i <= tx.data_misaligned_i;
        vif.drv_cb.branch_mux_i      <= tx.branch_mux_i;
        vif.drv_cb.jump_mux_i        <= tx.jump_mux_i;
        vif.drv_cb.instr_rdata_i     <= tx.instr_rdata_i;
        vif.drv_cb.illegal_c_insn_i  <= tx.illegal_c_insn_i;
    endtask

    task automatic idle();
        @(vif.drv_cb);
        vif.drv_cb.valid <= 0;
    endtask

    task run();
        Decoder_Transaction tx;
        wait (init_done);
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            drive(tx);
            tx.display("DRV");
            drv_count++;
        end
    endtask
endclass
