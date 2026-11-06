class Pref_Generator;
    mailbox #(Pref_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    function new(mailbox #(Pref_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    task send(logic req, logic br, logic [31:0] addr, logic rdy, logic gnt, int unsigned lat);
        Pref_Transaction tx;
        tx = new();
        tx.req_i       = req;
        tx.branch_i    = br;
        tx.addr_i      = {addr[31:1], 1'b0};
        tx.ready_i     = rdy;
        tx.instr_gnt_i = gnt;
        tx.lat         = lat;
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    function logic [31:0] rand_target(bit unaligned);
        return {14'h0, $urandom_range(0, 16'hFFFF), unaligned, 1'b0};
    endfunction

    task directed();
        send(1, 1, 32'h0000_0080, 0, 1, 0);
        repeat (60) send(1, 0, 0, 1, 1, 0);
        send(1, 1, rand_target(1), 1, 1, 0);
        repeat (60) send(1, 0, 0, 1, 1, 0);
        send(1, 1, rand_target(0), 1, 0, 0);
        repeat (80) send(1, 0, 0, 1, ($urandom_range(0, 2) != 0), $urandom_range(0, 3));
        send(1, 1, rand_target(0), 0, 1, 0);
        repeat (20) send(1, 0, 0, 0, 1, 0);
        repeat (40) send(1, 0, 0, 1, 1, 1);
        for (int k = 0; k < 30; k++) begin
            send(1, 1, rand_target(k[0]), $urandom_range(0, 1), $urandom_range(0, 1), 0);
            repeat ($urandom_range(0, 3)) send(1, 0, 0, 1, $urandom_range(0, 1), $urandom_range(0, 3));
        end
        send(1, 1, rand_target(0), 1, 1, 0);
        repeat (20) send(0, 0, 0, 1, 1, 0);
        repeat (40) send($urandom_range(0, 1), 0, 0, 1, 1, $urandom_range(0, 2));
        for (int k = 0; k < 20; k++) begin
            send(1, 1, rand_target(1), 1, 0, 0);
            repeat (2) send(1, 0, 0, 1, 0, 0);
            send(1, 0, 0, 1, 1, 3);
            send(1, 1, rand_target(0), 1, 1, 0);
            repeat (12) send(1, 0, 0, 1, 1, $urandom_range(0, 1));
        end
    endtask

    task run();
        Pref_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d cycles", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.lat = tx.lat % 4;
            tx.addr_i[0] = 1'b0;
            if (tx.branch_i)
                tx.req_i = 1'b1;
            gen2drv.put(tx.do_copy());
            gen_count++;
        end
        done = 1;
    endtask
endclass
