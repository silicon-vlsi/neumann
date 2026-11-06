class Fifo_Scoreboard;
    mailbox #(Fifo_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;
    int instr_count = 0;
    int comp_count  = 0;
    int clear_count = 0;

    logic [31:0] q_addr[$];
    logic [31:0] q_data[$];
    logic [31:0] pc;
    bit          started;

    function new(mailbox #(Fifo_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        started = 0;
    endfunction

    function bit get_hw(logic [31:0] addr, ref logic [31:0] a_addr[$], ref logic [31:0] a_data[$], output logic [15:0] hw);
        foreach (a_addr[i]) begin
            if (a_addr[i][31:2] == addr[31:2]) begin
                hw = addr[1] ? a_data[i][31:16] : a_data[i][15:0];
                return 1;
            end
        end
        hw = 16'h0;
        return 0;
    endfunction

    task run();
        Fifo_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Fifo_Transaction tx);
        logic [31:0] a_addr[$];
        logic [31:0] a_data[$];
        logic [15:0] h0, h1;
        bit          v0, v1, comp, exp_valid;
        string       diff;
        diff = "";

        if (tx.clear_i) begin
            q_addr.delete();
            q_data.delete();
            started = 0;
            clear_count++;
            pass_count++;
            return;
        end

        if (tx.in_ready_o !== (q_addr.size() < 2))
            diff = {diff, $sformatf(" in_ready exp=%b got=%b (stored=%0d)", (q_addr.size() < 2), tx.in_ready_o, q_addr.size())};
        if (tx.in_valid_i && q_addr.size() >= 3)
            diff = {diff, " push while 3 words stored"};

        a_addr = q_addr;
        a_data = q_data;
        if (tx.in_valid_i) begin
            a_addr.push_back(tx.in_addr_i);
            a_data.push_back(tx.in_rdata_i);
            if (!started) begin
                pc      = tx.in_addr_i;
                started = 1;
            end
        end

        exp_valid = 0;
        comp      = 0;
        if (started) begin
            v0 = get_hw(pc, a_addr, a_data, h0);
            if (v0) begin
                comp = (h0[1:0] != 2'b11);
                if (comp)
                    exp_valid = 1;
                else begin
                    v1 = get_hw(pc + 32'h2, a_addr, a_data, h1);
                    exp_valid = v1;
                end
            end
        end

        if (tx.out_valid_o !== exp_valid)
            diff = {diff, $sformatf(" out_valid exp=%b got=%b pc=%h", exp_valid, tx.out_valid_o, pc)};
        if (exp_valid) begin
            if (tx.out_addr_o !== pc)
                diff = {diff, $sformatf(" out_addr exp=%h got=%h", pc, tx.out_addr_o)};
            if (tx.out_rdata_o[15:0] !== h0)
                diff = {diff, $sformatf(" out_rdata[15:0] exp=%h got=%h", h0, tx.out_rdata_o[15:0])};
            if (!comp && tx.out_rdata_o[31:16] !== h1)
                diff = {diff, $sformatf(" out_rdata[31:16] exp=%h got=%h", h1, tx.out_rdata_o[31:16])};
        end

        if (exp_valid && tx.out_ready_i) begin
            instr_count++;
            if (comp) comp_count++;
            pc = pc + (comp ? 32'h2 : 32'h4);
            while (a_addr.size() > 0 && a_addr[0][31:2] < pc[31:2]) begin
                void'(a_addr.pop_front());
                void'(a_data.pop_front());
            end
        end
        q_addr = a_addr;
        q_data = a_data;

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH in_v=%b in_a=%h out_rdy=%b :%s", tx.in_valid_i, tx.in_addr_i, tx.out_ready_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d instructions=%0d compressed=%0d clears=%0d",
                 total_count, pass_count, fail_count, instr_count, comp_count, clear_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0 && instr_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
