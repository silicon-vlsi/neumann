class generator;

    mailbox #(transaction) gen2drv;
    event                  done;

    bit [5:0] op_list[$];
    int       num_per_op = 200;

    function new(mailbox #(transaction) gen2drv, event done);
        this.gen2drv = gen2drv;
        this.done    = done;
    endfunction

    task run();
        transaction tr;

        foreach (op_list[i]) begin

            bit [31:0] corners[] = '{32'h0, 32'h1, 32'hFFFF_FFFF,
                                     32'h7FFF_FFFF, 32'h8000_0000,
                                     32'hA5A5_A5A5, 32'h5A5A_5A5A};
            foreach (corners[ai]) begin
                foreach (corners[bi]) begin
                    tr = new();
                    tr.operator  = op_list[i];
                    tr.operand_a = corners[ai];
                    tr.operand_b = corners[bi];
                    gen2drv.put(tr);
                end
            end

            for (int n = 0; n < num_per_op; n++) begin
                tr = new();
                if (!tr.randomize() with { operator == op_list[i]; })
                    $fatal(1, "randomize failed");
                gen2drv.put(tr);
            end
        end

        ->done;
    endtask

endclass
