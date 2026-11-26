class Monitor;
virtual imm_interface vif;
mailbox #(Transaction) mon2scb;
mailbox #(Transaction) mon2cov;
int Monitor_count=0;   

function new(virtual imm_interface vif,mailbox #(Transaction) mon2scb, mailbox #(Transaction) mon2cov);
this.vif=vif;
this.mon2scb=mon2scb;
this.mon2cov=mon2cov;
endfunction

task run();
Transaction tx;
#5;
forever begin
    tx = new();
    tx.instr_i = vif.instr_i;
    tx.imm_sel_i = vif.imm_sel_i;
    tx.imm_o = vif.imm_o;
    tx.display("MON");
    mon2scb.put(tx);
    mon2cov.put(tx);
    Monitor_count++;
    #10;
end
endtask

endclass
