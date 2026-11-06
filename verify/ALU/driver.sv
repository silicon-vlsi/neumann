class driver;

    virtual alu_if vif;
    mailbox #(transaction) gen2drv;
    int drv_count = 0;

    function new(virtual alu_if vif, mailbox #(transaction) gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        transaction tr;
        forever begin
            gen2drv.get(tr);
            @(vif.drv_cb);
            vif.drv_cb.operator_i  <= tr.operator;
            vif.drv_cb.operand_a_i <= tr.operand_a;
            vif.drv_cb.operand_b_i <= tr.operand_b;
            drv_count++;
        end
    endtask

endclass
