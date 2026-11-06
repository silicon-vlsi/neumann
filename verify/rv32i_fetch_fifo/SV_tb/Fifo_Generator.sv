class Fifo_Generator;
    mailbox #(Fifo_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    function new(mailbox #(Fifo_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    task send(logic clr, logic [31:0] tgt, logic push, logic rdy);
        Fifo_Transaction tx;
        tx = new();
        tx.clear_i     = clr;
        tx.target      = tgt;
        tx.push        = push;
        tx.out_ready_i = rdy;
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task directed();
        logic [31:0] base;
        for (int k = 0; k < 4; k++) begin
            base = {$urandom_range(16'h0, 16'h3FFF), 2'b00} + (k[0] ? 32'h2 : 32'h0);
            send(1, base, 0, 0);
            repeat (40) send(0, 0, 1, 1);
            send(1, base + 32'h40, 0, 0);
            repeat (10) send(0, 0, 1, 0);
            repeat (40) send(0, 0, 1, $urandom_range(0, 1));
            send(1, base + 32'h82, 0, 0);
            repeat (6) send(0, 0, 0, 1);
            repeat (30) send(0, 0, $urandom_range(0, 1), 1);
            repeat (20) send(0, 0, 1, ($urandom_range(0, 3) == 0));
        end
        for (int k = 0; k < 20; k++) begin
            send(1, {$urandom_range(16'h0, 16'h3FFF), 1'b1, 1'b0}, 0, 0);
            repeat ($urandom_range(1, 4)) send(0, 0, 1, 1);
        end
    endtask

    task run();
        Fifo_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d cycles", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            gen2drv.put(tx.do_copy());
            gen_count++;
        end
        done = 1;
    endtask
endclass
