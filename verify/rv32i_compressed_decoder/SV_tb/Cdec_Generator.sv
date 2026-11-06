class Cdec_Generator;
    mailbox #(Cdec_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;
    bit sweep     = 1;

    function new(mailbox #(Cdec_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
        if ($test$plusargs("NOSWEEP"))
            sweep = 0;
    endfunction

    task send(logic [31:0] instr);
        Cdec_Transaction tx;
        tx = new();
        tx.instr_i = instr;
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task directed();
        logic [15:0] hi;
        for (int i = 0; i < 65536; i++) begin
            if (i[1:0] == 2'b11)
                continue;
            hi = $urandom();
            send({hi, i[15:0]});
        end
    endtask

    task run();
        Cdec_Transaction tx;
        if (sweep) begin
            directed();
            $display("[GEN] exhaustive sweep done: %0d compressed encodings", gen_count);
        end
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.display("GEN");
            gen2drv.put(tx.do_copy());
            gen_count++;
        end
        done = 1;
    endtask
endclass
