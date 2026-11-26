`include "rv32i_defines.vh"
`include "Csr_tb_cfg.svh"
class Csr_Scoreboard;
    localparam NCNT = `CSR_N_PERF_CNT;

    mailbox #(Csr_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;
    int read_count  = 0;

    logic        mie, mpie;
    logic [31:0] mepc;
    logic [5:0]  mcause;
    logic [NCNT-1:0] pcer;
    logic [1:0]  pcmr;
    logic [31:0] pccr   [NCNT];
    logic        inc_q  [NCNT];

    function new(mailbox #(Csr_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        mie    = 0;
        mpie   = 0;
        mepc   = 0;
        mcause = 0;
        pcer   = 0;
        pcmr   = 2'b11;
        for (int i = 0; i < NCNT; i++) begin
            pccr[i]  = 0;
            inc_q[i] = 0;
        end
    endfunction

    function bit is_perf_cnt(logic [11:0] a);
        return a[11:5] == 7'b0111100;
    endfunction

    function logic [31:0] csr_op(logic [1:0] op, logic [31:0] old, logic [31:0] w);
        case (op)
            `CSR_OP_WRITE: return w;
            `CSR_OP_SET:   return old | w;
            `CSR_OP_CLEAR: return old & ~w;
            default:       return old;
        endcase
    endfunction

    function logic [31:0] read_value(Csr_Transaction tx);
        logic [11:0] a;
        int idx;
        a = tx.csr_addr_i;
        if (tx.csr_access_i) begin
            if (is_perf_cnt(a)) begin
                idx = a[4:0];
                return (idx < NCNT) ? pccr[idx] : 32'h0;
            end
            if (a == 12'h7A0) return {{(32-NCNT){1'b0}}, pcer};
            if (a == 12'h7A1) return {30'h0, pcmr};
        end
        case (a)
            12'h300: return {19'b0, 2'b11, 3'b0, mpie, 3'b0, mie, 3'b0};
            12'h305: return {tx.boot_addr_i, 8'h0};
            12'h341: return mepc;
            12'h342: return {mcause[5], 26'b0, mcause[4:0]};
            12'hF14: return {21'b0, tx.cluster_id_i, 1'b0, tx.core_id_i};
            default: return 32'h0;
        endcase
    endfunction

    function void resync_read(Csr_Transaction tx);
        int idx;
        if (!tx.csr_access_i || $isunknown(tx.csr_rdata_o))
            return;
        if (is_perf_cnt(tx.csr_addr_i)) begin
            idx = tx.csr_addr_i[4:0];
            if (idx < NCNT) pccr[idx] = tx.csr_rdata_o;
        end else if (tx.csr_addr_i == 12'h7A0)
            pcer = tx.csr_rdata_o[NCNT-1:0];
        else if (tx.csr_addr_i == 12'h7A1)
            pcmr = tx.csr_rdata_o[1:0];
    endfunction

    function void update(Csr_Transaction tx, logic [31:0] rdata);
        logic [31:0] w;
        logic        we;
        logic [10:0] ev_all;
        logic [NCNT-1:0] ev;
        logic [11:0] a;
        logic        n_mie, n_mpie;
        logic [31:0] n_mepc;
        logic [5:0]  n_mcause;
        logic [31:0] n_pccr [NCNT];
        int          idx;

        a  = tx.csr_addr_i;
        we = (tx.csr_op_i != `CSR_OP_NONE);
        w  = csr_op(tx.csr_op_i, rdata, tx.csr_wdata_i);

        n_mie = mie; n_mpie = mpie; n_mepc = mepc; n_mcause = mcause;
        if (we) begin
            case (a)
                12'h300: begin n_mie = w[3]; n_mpie = w[7]; end
                12'h341: n_mepc = w;
                12'h342: n_mcause = {w[31], w[4:0]};
                default: ;
            endcase
        end
        if (tx.csr_save_cause_i) begin
            if (tx.csr_save_if_i)
                n_mepc = tx.pc_if_i;
            else if (tx.csr_save_id_i)
                n_mepc = tx.pc_id_i;
            n_mpie   = mie;
            n_mie    = 1'b0;
            n_mcause = tx.csr_cause_i;
        end else if (tx.csr_restore_mret_i) begin
            n_mie  = mpie;
            n_mpie = 1'b1;
        end

        // full event list (same order as perf_events in the RTL), then keep the first NCNT
        ev_all = '0;
        ev_all[0]  = 1'b1;
        ev_all[1]  = tx.id_valid_i & tx.is_decoding_i;
        ev_all[4]  = tx.imiss_i & ~tx.pc_set_i;
        ev_all[5]  = tx.mem_load_i;
        ev_all[6]  = tx.mem_store_i;
        ev_all[7]  = tx.jump_i;
        ev_all[8]  = tx.branch_i;
        ev_all[9]  = tx.branch_taken_i;
        ev_all[10] = tx.id_valid_i & tx.is_decoding_i & tx.is_compressed_i;
        ev = ev_all[NCNT-1:0];

        for (int i = 0; i < NCNT; i++) begin
            n_pccr[i] = pccr[i];
            if (inc_q[i] && ((pccr[i] != 32'hFFFF_FFFF) || !pcmr[1]))
                n_pccr[i] = pccr[i] + 1;
        end
        if (tx.csr_access_i && is_perf_cnt(a) && tx.csr_op_i != `CSR_OP_NONE) begin
            idx = a[4:0];
            for (int i = 0; i < NCNT; i++)
                if (a == 12'h79F || idx == i)
                    n_pccr[i] = csr_op(tx.csr_op_i, pccr[i], tx.csr_wdata_i);
        end

        for (int i = 0; i < NCNT; i++)
            inc_q[i] = ev[i] & pcer[i] & pcmr[0];
        if (tx.csr_access_i && a == 12'h7A1)
            pcmr = csr_op(tx.csr_op_i, {30'h0, pcmr}, tx.csr_wdata_i);
        if (tx.csr_access_i && a == 12'h7A0)
            pcer = csr_op(tx.csr_op_i, {{(32-NCNT){1'b0}}, pcer}, tx.csr_wdata_i);

        mie = n_mie; mpie = n_mpie; mepc = n_mepc; mcause = n_mcause;
        for (int i = 0; i < NCNT; i++) pccr[i] = n_pccr[i];
    endfunction

    task run();
        Csr_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Csr_Transaction tx);
        logic [31:0] exp_rdata;
        string       diff;
        diff = "";
        exp_rdata = read_value(tx);

        if (tx.m_irq_enable_o !== mie) begin
            diff = {diff, $sformatf(" m_irq_enable exp=%b got=%b", mie, tx.m_irq_enable_o)};
            mie = tx.m_irq_enable_o;
        end
        if (tx.mepc_o !== mepc) begin
            diff = {diff, $sformatf(" mepc_o exp=%h got=%h", mepc, tx.mepc_o)};
            mepc = tx.mepc_o;
        end
        if (tx.csr_access_i) begin
            read_count++;
            if (tx.csr_rdata_o !== exp_rdata) begin
                diff = {diff, $sformatf(" rdata[%h] exp=%h got=%h", tx.csr_addr_i, exp_rdata, tx.csr_rdata_o)};
                resync_read(tx);
                exp_rdata = read_value(tx);
            end
        end

        update(tx, exp_rdata);

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH acc=%b addr=%h op=%0d wdata=%h save=%b mret=%b :%s",
                   tx.csr_access_i, tx.csr_addr_i, tx.csr_op_i, tx.csr_wdata_i,
                   tx.csr_save_cause_i, tx.csr_restore_mret_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d csr_reads=%0d",
                 total_count, pass_count, fail_count, read_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
