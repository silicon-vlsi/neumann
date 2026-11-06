class monitor;

    virtual alu_if vif;
    mailbox #(transaction) mon2scb;
    mailbox #(transaction) mon2cov;
    int mon_count = 0;

    function new(virtual alu_if vif,
                 mailbox #(transaction) mon2scb,
                 mailbox #(transaction) mon2cov);
        this.vif     = vif;
        this.mon2scb = mon2scb;
        this.mon2cov = mon2cov;
    endfunction

    task run();
        transaction tr;
        forever begin
            @(vif.mon_cb);
            tr = new();
            tr.operator          = vif.mon_cb.operator_i;
            tr.operand_a         = vif.mon_cb.operand_a_i;
            tr.operand_b         = vif.mon_cb.operand_b_i;
            tr.result            = vif.mon_cb.result_o;
            tr.comparison_result = vif.mon_cb.comparison_result_o;
            tr.is_equal_result   = vif.mon_cb.is_equal_result_o;
            tr.adder_result      = vif.mon_cb.adder_result_o;

            mon2scb.put(tr.copy());
            mon2cov.put(tr.copy());
            mon_count++;
        end
    endtask

endclass
