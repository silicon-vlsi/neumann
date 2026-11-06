class Controller_Generator;
    mailbox #(Controller_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;

    function new(mailbox #(Controller_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    task run();
        Controller_Transaction tx;
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.display("GEN");
            gen2drv.put(tx.do_copy());
            gen_count++;
        end
    endtask
endclass