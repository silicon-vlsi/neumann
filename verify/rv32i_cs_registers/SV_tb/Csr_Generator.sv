`include "Csr_tb_cfg.svh"
class Csr_Generator;
    localparam NCNT = `CSR_N_PERF_CNT;
    mailbox #(Csr_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    function new(mailbox #(Csr_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    function Csr_Transaction blank();
        Csr_Transaction tx;
        tx = new();
        tx.csr_access_i = 0;
        tx.csr_addr_i = 0;
        tx.csr_wdata_i = 0;
        tx.csr_op_i = `CSR_OP_NONE;
        tx.pc_if_i = $urandom();
        tx.pc_id_i = $urandom();
        tx.csr_save_if_i = 0;
        tx.csr_save_id_i = 0;
        tx.csr_restore_mret_i = 0;
        tx.csr_cause_i = 0;
        tx.csr_save_cause_i = 0;
        tx.if_valid_i = 0;
        tx.id_valid_i = 0;
        tx.is_compressed_i = 0;
        tx.is_decoding_i = 0;
        tx.imiss_i = 0;
        tx.pc_set_i = 0;
        tx.jump_i = 0;
        tx.branch_i = 0;
        tx.branch_taken_i = 0;
        tx.mem_load_i = 0;
        tx.mem_store_i = 0;
        return tx;
    endfunction

    task put(Csr_Transaction tx);
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task csr(logic [11:0] addr, logic [1:0] op, logic [31:0] wdata);
        Csr_Transaction tx;
        tx = blank();
        tx.csr_access_i = 1;
        tx.csr_addr_i   = addr;
        tx.csr_op_i     = op;
        tx.csr_wdata_i  = wdata;
        put(tx);
    endtask

    task idle(int n);
        repeat (n) put(blank());
    endtask

    task events(int n);
        Csr_Transaction tx;
        repeat (n) begin
            tx = blank();
            {tx.if_valid_i, tx.id_valid_i, tx.is_compressed_i, tx.is_decoding_i, tx.imiss_i, tx.pc_set_i,
             tx.jump_i, tx.branch_i, tx.branch_taken_i, tx.mem_load_i, tx.mem_store_i} = $urandom();
            put(tx);
        end
    endtask

    task save(bit from_if, logic [5:0] cause);
        Csr_Transaction tx;
        tx = blank();
        tx.csr_save_cause_i = 1;
        tx.csr_save_if_i    = from_if;
        tx.csr_save_id_i    = !from_if;
        tx.csr_cause_i      = cause;
        put(tx);
    endtask

    task mret();
        Csr_Transaction tx;
        tx = blank();
        tx.csr_restore_mret_i = 1;
        put(tx);
    endtask

    task directed();
        logic [11:0] named[$];
        named = '{12'h300, 12'h305, 12'h341, 12'h342, 12'hF14, 12'h7A0, 12'h7A1};
        idle(2);
        foreach (named[i]) csr(named[i], `CSR_OP_NONE, 32'h0);
        for (int k = 0; k < NCNT; k++) csr(12'h780 + k, `CSR_OP_NONE, 32'h0);
        foreach (named[i]) begin
            csr(named[i], `CSR_OP_WRITE, 32'hFFFF_FFFF);
            csr(named[i], `CSR_OP_NONE,  32'h0);
            csr(named[i], `CSR_OP_WRITE, 32'h0);
            csr(named[i], `CSR_OP_NONE,  32'h0);
            csr(named[i], `CSR_OP_SET,   32'h0000_0088);
            csr(named[i], `CSR_OP_NONE,  32'h0);
            csr(named[i], `CSR_OP_WRITE, $urandom());
            csr(named[i], `CSR_OP_CLEAR, 32'h0000_0008);
            csr(named[i], `CSR_OP_NONE,  32'h0);
        end
        csr(12'h300, `CSR_OP_WRITE, 32'h0000_0008);
        save(1, 6'h25);
        csr(12'h341, `CSR_OP_NONE, 32'h0);
        csr(12'h342, `CSR_OP_NONE, 32'h0);
        csr(12'h300, `CSR_OP_NONE, 32'h0);
        mret();
        csr(12'h300, `CSR_OP_NONE, 32'h0);
        save(0, 6'h0B);
        csr(12'h341, `CSR_OP_NONE, 32'h0);
        csr(12'h342, `CSR_OP_NONE, 32'h0);
        mret();
        csr(12'h300, `CSR_OP_NONE, 32'h0);
        csr(12'h7A0, `CSR_OP_WRITE, 32'h0000_07FF);
        csr(12'h7A1, `CSR_OP_WRITE, 32'h0000_0001);
        csr(12'h79F, `CSR_OP_WRITE, 32'h0);
        events(200);
        for (int k = 0; k < NCNT; k++) csr(12'h780 + k, `CSR_OP_NONE, 32'h0);
        csr(12'h780, `CSR_OP_WRITE, 32'hFFFF_FFFC);
        idle(8);
        csr(12'h780, `CSR_OP_NONE, 32'h0);
        csr(12'h7A1, `CSR_OP_WRITE, 32'h0000_0003);
        csr(12'h780, `CSR_OP_WRITE, 32'hFFFF_FFFC);
        idle(8);
        csr(12'h780, `CSR_OP_NONE, 32'h0);
        csr(12'h79F, `CSR_OP_WRITE, 32'h1234_5678);
        for (int k = 0; k < NCNT; k++) csr(12'h780 + k, `CSR_OP_NONE, 32'h0);
        csr(12'h7A0, `CSR_OP_CLEAR, 32'h0000_0001);
        csr(12'h7A0, `CSR_OP_NONE, 32'h0);
        csr(12'h7A1, `CSR_OP_CLEAR, 32'h0000_0002);
        csr(12'h7A1, `CSR_OP_NONE, 32'h0);
        csr(12'h781, `CSR_OP_CLEAR, 32'h0000_00FF);
        csr(12'h781, `CSR_OP_NONE, 32'h0);
        for (int k = NCNT; k < 32; k++) csr(12'h780 + k, `CSR_OP_NONE, 32'h0);
        for (int k = 0; k < NCNT; k++) begin
            csr(12'h780 + k, `CSR_OP_SET,   32'h0000_0010);
            csr(12'h780 + k, `CSR_OP_CLEAR, 32'h0000_0010);
            csr(12'h780 + k, `CSR_OP_WRITE, 32'h0000_0100);
        end
        csr(12'h79F, `CSR_OP_NONE,  32'h0);
        csr(12'h79F, `CSR_OP_SET,   32'h1);
        csr(12'h79F, `CSR_OP_CLEAR, 32'h1);
        csr(12'h78B, `CSR_OP_WRITE, 32'h1);
        csr(12'h78C, `CSR_OP_SET,   32'h1);
        csr(12'h78D, `CSR_OP_CLEAR, 32'h1);
        csr(12'h7A1, `CSR_OP_WRITE, 32'h0000_0000);
        events(20);
        csr(12'h785, `CSR_OP_NONE, 32'h0);
    endtask

    task run();
        Csr_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d cycles", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.legalize();
            put(tx);
        end
        done = 1;
    endtask
endclass
