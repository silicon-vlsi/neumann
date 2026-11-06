class Pref_Scoreboard;
    mailbox #(Pref_Transaction) mon2scb;
    int pass_count   = 0;
    int fail_count   = 0;
    int total_count  = 0;
    int instr_count  = 0;
    int comp_count   = 0;
    int branch_count = 0;

    logic [31:0] pc;
    bit          started;

    function new(mailbox #(Pref_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        started = 0;
    endfunction

    function logic [15:0] mem_hw(logic [31:0] addr);
        logic [31:0] w;
        w = Pref_Transaction::mem_word(addr);
        return addr[1] ? w[31:16] : w[15:0];
    endfunction

    task run();
        Pref_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Pref_Transaction tx);
        logic [15:0] h0, h1;
        bit          comp;
        string       diff;
        diff = "";

        if (tx.branch_i) begin
            pc      = {tx.addr_i[31:1], 1'b0};
            started = 1;
            branch_count++;
            pass_count++;
            return;
        end

        if (started && tx.valid_o && tx.ready_i) begin
            h0   = mem_hw(pc);
            h1   = mem_hw(pc + 32'h2);
            comp = (h0[1:0] != 2'b11);
            if (tx.addr_o !== pc)
                diff = {diff, $sformatf(" addr_o exp=%h got=%h", pc, tx.addr_o)};
            if (tx.rdata_o[15:0] !== h0)
                diff = {diff, $sformatf(" rdata[15:0] exp=%h got=%h", h0, tx.rdata_o[15:0])};
            if (!comp && tx.rdata_o[31:16] !== h1)
                diff = {diff, $sformatf(" rdata[31:16] exp=%h got=%h", h1, tx.rdata_o[31:16])};
            instr_count++;
            if (comp) comp_count++;
            pc = pc + (comp ? 32'h2 : 32'h4);
        end

        if (tx.busy_o !== 1'b1 && tx.instr_req_o === 1'b1)
            diff = {diff, " busy_o low while requesting"};

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH pc=%h :%s", pc, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d instructions=%0d compressed=%0d branches=%0d",
                 total_count, pass_count, fail_count, instr_count, comp_count, branch_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0 && instr_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
