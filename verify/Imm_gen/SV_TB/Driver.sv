class Driver;
virtual imm_interface vif;
mailbox #(Transaction) gen2drv;
int drv_count = 0;

function new(mailbox #(Transaction) gen2drv, virtual imm_interface vif);
this.gen2drv = gen2drv;
this.vif = vif;
endfunction

task run();
Transaction tx;
forever begin
    gen2drv.get(tx);
    vif.instr_i=tx.instr_i;
    vif.imm_sel_i=tx.imm_sel_i;
    tx.display("DRV");
    #10;
    drv_count++;
end
endtask

endclass
