class Ex_Driver;
    mailbox #(Ex_Transaction) gen2drv;
    virtual Ex_interface vif;
    int drv_count = 0;
    bit init_done = 0;

    function new(mailbox #(Ex_Transaction) gen2drv, virtual Ex_interface vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    task automatic reset();
        vif.drv_cb.valid           <= 0;
        vif.drv_cb.rst_n           <= 0;
        vif.drv_cb.alu_operator_i  <= `ALU_ADD;
        vif.drv_cb.alu_operand_a_i <= 0;
        vif.drv_cb.alu_operand_b_i <= 0;
        vif.drv_cb.lsu_en_i        <= 0;
        vif.drv_cb.lsu_ready_ex_i  <= 0;
        repeat (2) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;
        @(vif.drv_cb);
        init_done = 1;
        $display("[DRV] reset done");
    endtask

    task automatic drive(Ex_Transaction tx);
        vif.drv_cb.valid           <= 1;
        vif.drv_cb.alu_operator_i  <= tx.alu_operator_i;
        vif.drv_cb.alu_operand_a_i <= tx.alu_operand_a_i;
        vif.drv_cb.alu_operand_b_i <= tx.alu_operand_b_i;
        vif.drv_cb.lsu_en_i        <= tx.lsu_en_i;
        vif.drv_cb.lsu_ready_ex_i  <= tx.lsu_ready_ex_i;
    endtask

    task automatic idle();
        @(vif.drv_cb);
        vif.drv_cb.valid <= 0;
    endtask

    task run();
        Ex_Transaction tx;
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
