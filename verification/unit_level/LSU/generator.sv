class generator;

    mailbox #(transaction) gen2drv;
    event                  done;
    int                    num_rand = 200;

    function new(mailbox #(transaction) gen2drv, event done);
        this.gen2drv = gen2drv;
        this.done    = done;
    endfunction

    task run();
        transaction tr;

        for (int t = 0; t < 3; t++) begin
            for (int off = 0; off < 4; off++) begin
                for (int w = 0; w < 2; w++) begin
                    for (int s = 0; s < 2; s++) begin
                        tr = new();
                        tr.dtype   = t[1:0];
                        tr.addr    = 32'h0000_0040 + off;
                        tr.we      = w[0];
                        tr.sext    = s[0];
                        tr.wdata   = 32'hDEAD_0000 | (off<<8) | t;
                        tr.reg_off = 2'b00;
                        gen2drv.put(tr);
                    end
                end
            end
        end

        for (int n = 0; n < num_rand; n++) begin
            tr = new();
            if (!tr.randomize())
                $fatal(1, "txn randomize failed");
            gen2drv.put(tr);
        end

        ->done;
    endtask

endclass
