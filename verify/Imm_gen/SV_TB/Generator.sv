class Generator;
mailbox #(Transaction) gen2drv;
int number_tx=0;
int gen_count=0;


function new(mailbox #(Transaction) gen2drv, int number_tx);
this.gen2drv=gen2drv;
this.number_tx=number_tx;
endfunction

task run();
Transaction tx;
repeat (number_tx)
begin
    tx = new();
    if(!tx.randomize())
    begin
        $fatal(1, "Randomization failed");
    end
    tx.display("GEN");  
    gen2drv.put(tx);
    gen_count++;
end
endtask

endclass
