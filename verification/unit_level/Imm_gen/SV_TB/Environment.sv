class Environment;
Transaction tx;
Driver drv;
Generator gen;
Monitor mon;
Scoreboard scb;
Coverage_file cov;
mailbox #(Transaction) mon2scb;
mailbox #(Transaction) mon2cov;
mailbox #(Transaction) gen2drv;

virtual imm_interface vif;
int num_transactions;

function new(virtual imm_interface vif, int num_transactions=1000);
this.vif=vif;
this.num_transactions=num_transactions;
endfunction

task build();
gen2drv=new();
mon2cov=new();
mon2scb=new();

gen=new(.gen2drv(gen2drv),.number_tx(num_transactions));
drv=new(.gen2drv(gen2drv),.vif(vif));
mon=new(.vif(vif),.mon2scb(mon2scb),.mon2cov(mon2cov));
scb=new(.mon2scb(mon2scb));
cov=new(.mon2cov(mon2cov));
endtask

task run();
fork
    gen.run();
    drv.run();
    mon.run();
    scb.run();
    cov.run();
join_none

wait(drv.drv_count==num_transactions);
#1;
endtask

task report();
    $display("Generator created : %0d transactions", gen.gen_count);
    $display("Driver drove      : %0d transactions", drv.drv_count);
    $display("Monitor observed  : %0d transactions", mon.Monitor_count);  
    scb.report();
    cov.report();
endtask

task test();
build();
run();
report();
endtask

endclass



