`include "rv32i_defines.vh"
class Dbg_Scoreboard;
    mailbox #(Dbg_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;
    int read_count  = 0;
    int halt_count  = 0;

    typedef enum logic [2:0] {RD_NONE = 3'd0, RD_CSR = 3'd1, RD_GPR = 3'd2, RD_DBGA = 3'd3, RD_DBGS = 3'd4} rsel_e;
    typedef enum logic [1:0] {RUNNING = 2'd0, HALT_REQ = 2'd1, HALT = 2'd2} stall_e;

    rsel_e       rsel_q;
    bit          second_q;
    logic [`DBG_SETS_W-1:0] settings_q;
    logic [14:0] addr_q;
    logic [31:0] wdata_q;
    logic        rreq_q, csr_req_q, jump_q, rvalid_q;
    stall_e      stall_q;
    logic [5:0]  cause_q;
    logic        ssth_q;

    logic        gnt, rreq_n, wreq, csr_req_n, csr_we, jump_n, do_resume, do_halt, ssth_clear, second_n;
    rsel_e       rsel_n;
    logic [`DBG_SETS_W-1:0] settings_n;
    logic        halted, stall, dreq;
    stall_e      stall_n;
    logic [5:0]  cause_n;
    logic        ssth_n;

    function new(mailbox #(Dbg_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        rsel_q = RD_NONE; second_q = 0; settings_q = 0; addr_q = 0; wdata_q = 0;
        rreq_q = 0; csr_req_q = 0; jump_q = 0; rvalid_q = 0;
        stall_q = RUNNING; cause_q = `DBG_CAUSE_HALT; ssth_q = 0;
    endfunction

    function void bus_decode(Dbg_Transaction t);
        logic [5:0] page;
        logic [4:0] reg_sel;
        gnt = 0; rreq_n = 0; wreq = 0; csr_req_n = 0; csr_we = 0; jump_n = 0;
        do_resume = 0; do_halt = 0; ssth_clear = 0; second_n = 0;
        rsel_n = RD_NONE; settings_n = settings_q;
        if (!t.debug_req_i) return;
        page    = t.debug_addr_i[13:8];
        reg_sel = t.debug_addr_i[6:2];
        if (t.debug_we_i) begin
            if (t.debug_addr_i[14]) begin
                if (!second_q) begin
                    second_n  = 1;
                    csr_req_n = halted;
                end else begin
                    gnt    = 1;
                    csr_we = 1;
                end
            end else begin
                gnt = 1;
                if (page == 6'h00) begin
                    case (reg_sel)
                        5'd0: begin
                            if (t.debug_wdata_i[16]) do_halt = !halted;
                            else                     do_resume = halted;
                            settings_n[`DBG_SETS_SSTE] = t.debug_wdata_i[0];
                        end
                        5'd1: ssth_clear = t.debug_wdata_i[0];
                        5'd2: begin
                            settings_n[`DBG_SETS_ECALL] = t.debug_wdata_i[11];
                            settings_n[`DBG_SETS_ELSU]  = t.debug_wdata_i[7] | t.debug_wdata_i[5];
                            settings_n[`DBG_SETS_EBRK]  = t.debug_wdata_i[3];
                            settings_n[`DBG_SETS_EILL]  = t.debug_wdata_i[2];
                        end
                        default: ;
                    endcase
                end else if (page == 6'h20)
                    jump_n = halted && (reg_sel == 5'd0);
                else if (page == 6'h04)
                    wreq = halted;
            end
        end else begin
            gnt = 1;
            if (t.debug_addr_i[14]) begin
                if (halted) begin
                    csr_req_n = 1;
                    rsel_n    = RD_CSR;
                end
            end else if (page == 6'h00)
                rsel_n = RD_DBGA;
            else if (page == 6'h20)
                rsel_n = RD_DBGS;
            else if (page == 6'h04 && halted) begin
                rreq_n = 1;
                rsel_n = RD_GPR;
            end
        end
    endfunction

    function void stall_fsm(Dbg_Transaction t);
        stall_n = stall_q; dreq = 0; stall = 0;
        cause_n = cause_q; ssth_n = ssth_q;
        case (stall_q)
            RUNNING: begin
                ssth_n = 0;
                if (do_halt || t.debug_halt_i || t.trap_i) begin
                    dreq    = 1;
                    stall_n = HALT_REQ;
                    if (t.trap_i) begin
                        if (settings_q[`DBG_SETS_SSTE]) ssth_n = 1;
                        cause_n = t.exc_cause_i;
                    end else
                        cause_n = `DBG_CAUSE_HALT;
                end
            end
            HALT_REQ: begin
                dreq = 1;
                if (t.dbg_ack_i) stall_n = HALT;
                if (do_resume || t.debug_resume_i) stall_n = RUNNING;
            end
            HALT: begin
                stall = 1;
                if (do_resume || t.debug_resume_i) begin
                    stall_n = RUNNING;
                    stall   = 0;
                end
            end
            default: stall_n = RUNNING;
        endcase
        if (ssth_clear) ssth_n = 0;
    endfunction

    function logic [31:0] read_data(Dbg_Transaction t);
        logic [31:0] d;
        d = 32'h0;
        case (rsel_q)
            RD_CSR: d = t.csr_rdata_i;
            RD_GPR: d = t.regfile_rdata_i;
            RD_DBGA: begin
                case (addr_q[6:2])
                    5'h0: d = {15'b0, halted, 15'b0, settings_q[`DBG_SETS_SSTE]};
                    5'h1: d = {15'b0, t.sleeping_i, 15'b0, ssth_q};
                    5'h2: begin
                        d[11] = settings_q[`DBG_SETS_ECALL];
                        d[7]  = settings_q[`DBG_SETS_ELSU];
                        d[5]  = settings_q[`DBG_SETS_ELSU];
                        d[3]  = settings_q[`DBG_SETS_EBRK];
                        d[2]  = settings_q[`DBG_SETS_EILL];
                    end
                    5'h3: d = {cause_q[5], 26'b0, cause_q[4:0]};
                    default: d = 32'h0;
                endcase
            end
            RD_DBGS: d = addr_q[2] ? t.pc_id_i : t.pc_if_i;
            default: d = 32'h0;
        endcase
        return d;
    endfunction

    task run();
        Dbg_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Dbg_Transaction t);
        string diff;
        logic [31:0] e_rdata;
        diff   = "";
        halted = (stall_q == HALT);
        bus_decode(t);
        stall_fsm(t);
        e_rdata = read_data(t);
        if (t.debug_rvalid_o === 1'b1) read_count++;
        if (stall_q == HALT && stall_n != HALT) halt_count++;

        `define DBG_CMP(sig, exp) if (t.sig !== exp) diff = {diff, $sformatf(" %s exp=%0h got=%0h", `"sig`", exp, t.sig)};
        `DBG_CMP(debug_gnt_o, gnt)
        `DBG_CMP(debug_rvalid_o, rvalid_q)
        `DBG_CMP(debug_rdata_o, e_rdata)
        `DBG_CMP(debug_halted_o, halted)
        `DBG_CMP(settings_o, settings_q)
        `DBG_CMP(stall_o, stall)
        `DBG_CMP(dbg_req_o, dreq)
        `DBG_CMP(regfile_rreq_o, rreq_q)
        `DBG_CMP(regfile_raddr_o, addr_q[6:2])
        `DBG_CMP(regfile_wreq_o, wreq)
        `DBG_CMP(regfile_waddr_o, t.debug_addr_i[6:2])
        `DBG_CMP(regfile_wdata_o, t.debug_wdata_i)
        `DBG_CMP(csr_req_o, csr_req_q)
        `DBG_CMP(csr_addr_o, addr_q[13:2])
        `DBG_CMP(csr_we_o, csr_we)
        `DBG_CMP(csr_wdata_o, wdata_q)
        `DBG_CMP(jump_req_o, jump_q)
        `DBG_CMP(jump_addr_o, wdata_q)
        `undef DBG_CMP

        rvalid_q   = gnt;
        settings_q = settings_n;
        if (t.debug_req_i) begin
            addr_q   = t.debug_addr_i;
            wdata_q  = t.debug_wdata_i;
            second_q = second_n;
        end
        if (t.debug_req_i || t.debug_rvalid_o) begin
            rreq_q    = rreq_n;
            csr_req_q = csr_req_n;
            jump_q    = jump_n;
            rsel_q    = rsel_n;
        end
        stall_q = stall_n;
        cause_q = cause_n;
        ssth_q  = ssth_n;

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH req=%b we=%b addr=%h stall=%s :%s", t.debug_req_i, t.debug_we_i, t.debug_addr_i, stall_q.name(), diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d reads=%0d resumes=%0d",
                 total_count, pass_count, fail_count, read_count, halt_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
