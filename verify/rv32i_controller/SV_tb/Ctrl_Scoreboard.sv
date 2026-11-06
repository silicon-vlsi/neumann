`include "rv32i_defines.vh"
class Ctrl_Scoreboard;
    mailbox #(Ctrl_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;
    int visits[13];

    typedef enum logic [3:0] {
        RESET = 4'd0, BOOT_SET = 4'd1, WAIT_SLEEP = 4'd2, SLEEP = 4'd3, FIRST_FETCH = 4'd4,
        DECODE = 4'd5, FLUSH = 4'd6, IRQ_TAKEN = 4'd7, DBG_SIGNAL = 4'd8, DBG_SIGNAL_SLEEP = 4'd9,
        DBG_WAIT = 4'd10, DBG_WAIT_BRANCH = 4'd11, DBG_WAIT_SLEEP = 4'd12
    } state_e;

    state_e cs;

    logic e_busy, e_first, e_dec, e_dwe, e_req, e_pcset, e_iack, e_eack, e_ekill;
    logic e_sif, e_sid, e_mret, e_scause, e_dack, e_trap, e_hif, e_hid, e_pj, e_ptb;
    logic [2:0] e_pcmux;
    logic [1:0] e_excmux;
    logic [4:0] e_irqid;
    logic [5:0] e_exccause;
    logic [5:0] e_csrcause;
    logic [1:0] e_fw;
    state_e     ns;

    function new(mailbox #(Ctrl_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        cs = RESET;
        foreach (visits[i]) visits[i] = 0;
    endfunction

    function void model(Ctrl_Transaction t);
        logic sste;
        logic wake;
        logic special;
        sste = t.dbg_settings_i[`DBG_SETS_SSTE];

        e_req = 1; e_eack = 0; e_ekill = 0; e_sif = 0; e_sid = 0; e_mret = 0; e_scause = 0;
        e_exccause = 0; e_excmux = `EXC_PC_IRQ; e_csrcause = 0; e_pcmux = `PC_BOOT; e_pcset = 0;
        e_busy = 1; e_dec = 0; e_first = 0; e_hif = 0; e_hid = 0; e_dack = 0; e_iack = 0;
        e_irqid = t.irq_id_ctrl_i; e_trap = 0; e_ptb = 0; e_pj = 0;
        ns = cs;

        case (cs)
            RESET: begin
                e_busy = 0;
                e_req  = 0;
                if (t.fetch_enable_i)  ns = BOOT_SET;
                else if (t.dbg_req_i)  ns = DBG_SIGNAL;
            end
            BOOT_SET: begin
                e_pcset = 1;
                e_pcmux = `PC_BOOT;
                ns      = FIRST_FETCH;
            end
            WAIT_SLEEP: begin
                e_busy = 0; e_req = 0; e_hif = 1; e_hid = 1;
                ns = SLEEP;
            end
            SLEEP: begin
                e_busy = 0; e_req = 0; e_hif = 1; e_hid = 1;
                e_trap = sste;
                wake   = t.fetch_enable_i || t.irq_req_ctrl_i;
                if (t.dbg_req_i) ns = wake ? DBG_SIGNAL : DBG_SIGNAL_SLEEP;
                else if (wake)   ns = FIRST_FETCH;
            end
            FIRST_FETCH: begin
                e_first = 1;
                if (t.id_ready_i && !t.dbg_stall_i) ns = DECODE;
                if (t.irq_req_ctrl_i && t.m_IE_i) begin
                    ns = IRQ_TAKEN; e_hif = 1; e_hid = 1;
                end
            end
            DECODE: begin
                special = t.mret_insn_i | t.ecall_insn_i | t.pipe_flush_i |
                          t.ebrk_insn_i | t.illegal_insn_i | t.csr_status_i;
                if (t.instr_valid_i) begin
                    e_dec = 1;
                    if (t.branch_set_i) begin
                        e_pcmux = `PC_JUMP; e_pcset = 1; e_ptb = 1; e_trap = sste;
                        if (t.dbg_req_i) ns = DBG_SIGNAL;
                    end else if (t.jump_set_i) begin
                        e_pcmux = `PC_JUMP; e_pcset = 1; e_pj = 1; e_trap = sste;
                    end else if (special) begin
                        ns = FLUSH; e_hif = 1; e_hid = 1;
                    end else begin
                        e_trap = sste;
                        if (t.irq_req_ctrl_i && t.m_IE_i && !t.instr_multicyle_i && !t.branch_in_id_i) begin
                            ns = IRQ_TAKEN; e_hif = 1; e_hid = 1;
                        end else if (t.dbg_req_i && !t.branch_taken_ex_i) begin
                            e_hif = 1;
                            if (t.id_ready_i) ns = DBG_SIGNAL;
                        end else
                            e_ekill = t.irq_req_ctrl_i && !t.instr_multicyle_i && !t.branch_in_id_i;
                    end
                end else if (t.irq_req_ctrl_i && t.m_IE_i) begin
                    ns = IRQ_TAKEN; e_hif = 1; e_hid = 1;
                end
            end
            DBG_SIGNAL: begin
                e_dack = 1; e_hif = 1; ns = DBG_WAIT;
            end
            DBG_SIGNAL_SLEEP: begin
                e_dack = 1; e_hif = 1; ns = DBG_WAIT_SLEEP;
            end
            DBG_WAIT_SLEEP, DBG_WAIT: begin
                e_hif = 1;
                if (t.dbg_jump_req_i) begin
                    e_pcmux = `PC_DBG_NPC; e_pcset = 1; ns = DBG_WAIT;
                end
                if (!t.dbg_stall_i) ns = (cs == DBG_WAIT) ? DECODE : SLEEP;
            end
            IRQ_TAKEN: begin
                e_pcmux = `PC_EXCEPTION; e_pcset = 1; e_excmux = `EXC_PC_IRQ;
                e_exccause = {1'b0, t.irq_id_ctrl_i};
                e_scause = 1; e_csrcause = {1'b1, t.irq_id_ctrl_i};
                e_sif = 1; e_iack = 1; e_eack = 1;
                ns = DECODE;
            end
            FLUSH: begin
                e_hif = t.fetch_enable_i ? t.dbg_req_i : 1'b1;
                e_hid = 1;
                if (t.ecall_insn_i) begin
                    e_pcmux = `PC_EXCEPTION; e_pcset = 1; e_sid = 1; e_scause = 1;
                    e_excmux = `EXC_PC_ECALL; e_exccause = `EXC_CAUSE_ECALL_MMODE; e_csrcause = `EXC_CAUSE_ECALL_MMODE;
                    e_trap = t.dbg_settings_i[`DBG_SETS_ECALL] | sste;
                end else if (t.illegal_insn_i) begin
                    e_pcmux = `PC_EXCEPTION; e_pcset = 1; e_sid = 1; e_scause = 1;
                    e_excmux = `EXC_PC_ILLINSN; e_exccause = `EXC_CAUSE_ILLEGAL_INSN; e_csrcause = `EXC_CAUSE_ILLEGAL_INSN;
                    e_trap = t.dbg_settings_i[`DBG_SETS_EILL] | sste;
                end else if (t.mret_insn_i) begin
                    e_pcmux = `PC_ERET; e_pcset = 1; e_mret = 1; e_trap = sste;
                end else if (t.ebrk_insn_i) begin
                    e_trap = t.dbg_settings_i[`DBG_SETS_EBRK] | sste;
                    e_exccause = `EXC_CAUSE_BREAKPOINT;
                end else if (t.csr_status_i || t.pipe_flush_i)
                    e_trap = sste;
                if (t.fetch_enable_i)
                    ns = t.dbg_req_i ? DBG_SIGNAL : DECODE;
                else if (t.dbg_req_i)
                    ns = DBG_SIGNAL_SLEEP;
                else
                    ns = (t.mret_insn_i || t.pipe_flush_i) ? WAIT_SLEEP : DECODE;
            end
            default: begin
                e_req = 0; ns = RESET;
            end
        endcase

        e_dwe = !e_dec || t.illegal_insn_i;
        e_fw  = t.data_misaligned_i ? `SEL_MISALIGNED : `SEL_REGFILE;
    endfunction

    task run();
        Ctrl_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Ctrl_Transaction t);
        string diff;
        diff = "";
        if (t.dbg_cs !== cs) begin
            diff = {diff, $sformatf(" state exp=%s got=%0d", cs.name(), t.dbg_cs)};
            cs = state_e'(t.dbg_cs);
        end
        visits[cs]++;
        model(t);
        `define CTRL_CMP(sig, exp) if (t.sig !== exp) diff = {diff, $sformatf(" %s exp=%0h got=%0h", `"sig`", exp, t.sig)};
        `CTRL_CMP(ctrl_busy_o, e_busy)
        `CTRL_CMP(first_fetch_o, e_first)
        `CTRL_CMP(is_decoding_o, e_dec)
        `CTRL_CMP(deassert_we_o, e_dwe)
        `CTRL_CMP(instr_req_o, e_req)
        `CTRL_CMP(pc_set_o, e_pcset)
        `CTRL_CMP(pc_mux_o, e_pcmux)
        `CTRL_CMP(exc_pc_mux_o, e_excmux)
        `CTRL_CMP(irq_ack_o, e_iack)
        `CTRL_CMP(irq_id_o, e_irqid)
        `CTRL_CMP(exc_cause_o, e_exccause)
        `CTRL_CMP(exc_ack_o, e_eack)
        `CTRL_CMP(exc_kill_o, e_ekill)
        `CTRL_CMP(csr_save_if_o, e_sif)
        `CTRL_CMP(csr_save_id_o, e_sid)
        `CTRL_CMP(csr_cause_o, e_csrcause)
        `CTRL_CMP(csr_restore_mret_id_o, e_mret)
        `CTRL_CMP(csr_save_cause_o, e_scause)
        `CTRL_CMP(dbg_ack_o, e_dack)
        `CTRL_CMP(dbg_trap_o, e_trap)
        `CTRL_CMP(operand_a_fw_mux_sel_o, e_fw)
        `CTRL_CMP(halt_if_o, e_hif)
        `CTRL_CMP(halt_id_o, e_hid)
        `CTRL_CMP(perf_jump_o, e_pj)
        `CTRL_CMP(perf_tbranch_o, e_ptb)
        `undef CTRL_CMP
        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH state=%s :%s", cs.name(), diff);
        end
        cs = ns;
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d", total_count, pass_count, fail_count);
        $display("[SCB] state visits: RESET=%0d BOOT=%0d WSLEEP=%0d SLEEP=%0d FFETCH=%0d DECODE=%0d FLUSH=%0d IRQ=%0d DSIG=%0d DSIGS=%0d DWAIT=%0d DWAITS=%0d",
                 visits[0], visits[1], visits[2], visits[3], visits[4], visits[5], visits[6], visits[7],
                 visits[8], visits[9], visits[10], visits[12]);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
