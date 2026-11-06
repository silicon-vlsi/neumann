class Reg_Scoreboard #(parameter RV32E = 0, parameter DATA_WIDTH = 32);
    typedef Reg_Transaction #(RV32E, DATA_WIDTH) tx_t;
    localparam ADDR_WIDTH = RV32E ? 4 : 5;
    localparam NUM_WORDS  = 2**ADDR_WIDTH;

    mailbox #(tx_t) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;
    int skip_count  = 0;

    logic [DATA_WIDTH-1:0] mem   [NUM_WORDS];
    bit                    known [NUM_WORDS];
    logic [DATA_WIDTH-1:0] wdata_q;
    bit                    last_hit [NUM_WORDS];
    int                    reset_count = 0;

    function new(mailbox #(tx_t) mon2scb);
        this.mon2scb = mon2scb;
        foreach (known[i]) known[i] = 0;
        known[0] = 1;
        mem[0]   = '0;
        wdata_q  = '0;
        foreach (last_hit[i]) last_hit[i] = 0;
    endfunction

    function bit read_ok(logic [4:0] addr, logic [DATA_WIDTH-1:0] got, string port, ref string diff);
        int a;
        a = addr[ADDR_WIDTH-1:0];
        if (!known[a]) begin
            skip_count++;
            return 1;
        end
        if (got !== mem[a]) begin
            diff = {diff, $sformatf(" port_%s x%0d exp=%h got=%h", port, a, mem[a], got)};
            return 0;
        end
        return 1;
    endfunction

    function void apply_reset();
        wdata_q = '0;
        for (int k = 1; k < NUM_WORDS; k++)
            if (last_hit[k])
                mem[k] = '0;
    endfunction

    function void update(tx_t tx);
        int w;
        w = tx.waddr_a_i[ADDR_WIDTH-1:0];
        foreach (last_hit[i]) last_hit[i] = 0;
        if (tx.we_a_i && tx.rst_n)
            wdata_q = tx.wdata_a_i;
        if (tx.test_en_i) begin
            for (int k = 1; k < NUM_WORDS; k++) begin
                mem[k]      = wdata_q;
                known[k]    = 1;
                last_hit[k] = 1;
            end
        end else if (tx.we_a_i && w != 0) begin
            mem[w]      = wdata_q;
            known[w]    = 1;
            last_hit[w] = 1;
        end
    endfunction

    task run();
        tx_t tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            if (tx.rst_n !== 1'b1) begin
                reset_count++;
                apply_reset();
            end
            check(tx);
            update(tx);
        end
    endtask

    function void check(tx_t tx);
        string diff;
        bit    ok;
        diff = "";
        ok   = read_ok(tx.raddr_a_i, tx.rdata_a_o, "a", diff);
        ok   = read_ok(tx.raddr_b_i, tx.rdata_b_o, "b", diff) && ok;
        if (ok)
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH we=%b ten=%b waddr=%0d wdata=%h raddr_a=%0d raddr_b=%0d :%s",
                   tx.we_a_i, tx.test_en_i, tx.waddr_a_i, tx.wdata_a_i, tx.raddr_a_i, tx.raddr_b_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d unwritten_reads=%0d reset_cycles=%0d",
                 total_count, pass_count, fail_count, skip_count, reset_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
