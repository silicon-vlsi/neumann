class Ex_Monitor;
    virtual Ex_interface vif;
    mailbox #(Ex_Transaction) mon2scb;
    mailbox #(Ex_Transaction) mon2cov;
    int mon_count=0;

    function new
        (
            virtual Ex_interface vif,
            mailbox #(Ex_Transaction) mon2scb,
            mailbox #(Ex_Transaction) mon2cov,
            int mon_count
        );
        this.vif=vif;
        this.mon2scb=mon2scb;
        this.mon2cov=mon2cov;
        this.mon_count=mon_count;
    endfunction

    task run();
        Ex_Transaction tx;
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.valid !== 1'b1)
                continue;
            tx = new();
            tx.alu_operator_i        = vif.mon_cb.alu_operator_i;
            tx.alu_operand_a_i       = vif.mon_cb.alu_operand_a_i;
            tx.alu_operand_b_i       = vif.mon_cb.alu_operand_b_i;
            tx.lsu_en_i              = vif.mon_cb.lsu_en_i;
            tx.lsu_ready_ex_i        = vif.mon_cb.lsu_ready_ex_i;
            tx.alu_adder_result_ex_o = vif.mon_cb.alu_adder_result_ex_o;
            tx.regfile_wdata_ex_o    = vif.mon_cb.regfile_wdata_ex_o;
            tx.jump_target_o         = vif.mon_cb.jump_target_o;
            tx.branch_decision_o     = vif.mon_cb.branch_decision_o;
            tx.ex_ready_o            = vif.mon_cb.ex_ready_o;
            tx.display("MON");
            mon2scb.put(tx.do_copy());
            mon2cov.put(tx.do_copy());
            mon_count++;
        end
    endtask

endclass
