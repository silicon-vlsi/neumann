`include "rv32i_defines.vh"
class Id_Scoreboard;
    mailbox #(Id_Transaction) mon2scb;
    int pass_count   = 0;
    int fail_count   = 0;
    int total_count  = 0;
    int decode_count = 0;
    int write_count  = 0;
    int dbg_reads    = 0;
    int stalls       = 0;

    logic [31:0] rf [32];
    logic        wb_q;
    logic        branch_set_q;

    logic [`ALU_OP_WIDTH-1:0] d_alu_operator_o;
    logic [2:0] d_alu_op_a_mux_sel_o;
    logic [2:0] d_alu_op_b_mux_sel_o;
    logic       d_imm_a_mux_sel_o;
    logic [3:0] d_imm_b_mux_sel_o;
    logic       d_regfile_we_o;
    logic       d_csr_access_o;
    logic [1:0] d_csr_op_o;
    logic       d_csr_status_o;
    logic       d_data_req_o;
    logic       d_data_we_o;
    logic [1:0] d_data_type_o;
    logic       d_data_sign_extension_o;
    logic [1:0] d_data_reg_offset_o;
    logic       d_data_load_event_o;
    logic       d_illegal_insn_o;
    logic       d_ebrk_insn_o;
    logic       d_mret_insn_o;
    logic       d_ecall_insn_o;
    logic       d_pipe_flush_o;
    logic       d_jump_in_id_o;
    logic       d_branch_in_id_o;

    function new(mailbox #(Id_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        foreach (rf[i]) rf[i] = 32'h0;
        wb_q         = 1'b0;
        branch_set_q = 1'b0;
    endfunction

    function void decode(logic [31:0] ins, logic deassert_we, logic misaligned, logic branch_mux, logic jump_mux, logic illegal_c);
        logic [6:0]  opcode;
        logic [2:0]  f3;
        logic [6:0]  f7;
        logic [11:0] imm12;
        logic        we, req, jmp, br;
        logic [1:0]  csr_op;
        struct {
            logic [`ALU_OP_WIDTH-1:0] alu_operator_o;
            logic [2:0] alu_op_a_mux_sel_o;
            logic [2:0] alu_op_b_mux_sel_o;
            logic       imm_a_mux_sel_o;
            logic [3:0] imm_b_mux_sel_o;
            logic       csr_access_o;
            logic       csr_status_o;
            logic       data_we_o;
            logic [1:0] data_type_o;
            logic       data_sign_extension_o;
            logic [1:0] data_reg_offset_o;
            logic       data_load_event_o;
            logic       illegal_insn_o;
            logic       ebrk_insn_o;
            logic       mret_insn_o;
            logic       ecall_insn_o;
            logic       pipe_flush_o;
        } e;

        opcode = ins[6:0];
        f3     = ins[14:12];
        f7     = ins[31:25];
        imm12  = ins[31:20];

        e.alu_operator_o        = `ALU_SLTU;
        e.alu_op_a_mux_sel_o    = `OP_A_REGA_OR_FWD;
        e.alu_op_b_mux_sel_o    = `OP_B_REGB_OR_FWD;
        e.imm_a_mux_sel_o       = `IMMA_ZERO;
        e.imm_b_mux_sel_o       = `IMMB_I;
        e.csr_access_o          = 0;
        e.csr_status_o          = 0;
        e.data_we_o             = 0;
        e.data_type_o           = 2'b00;
        e.data_sign_extension_o = 0;
        e.data_reg_offset_o     = 2'b00;
        e.data_load_event_o     = 0;
        e.illegal_insn_o        = 0;
        e.ebrk_insn_o           = 0;
        e.mret_insn_o           = 0;
        e.ecall_insn_o          = 0;
        e.pipe_flush_o          = 0;
        we = 0; req = 0; jmp = 0; br = 0;
        csr_op = `CSR_OP_NONE;

        case (opcode)
            `OPCODE_JAL: begin
                jmp = 1;
                e.alu_op_a_mux_sel_o = `OP_A_CURRPC;
                e.alu_op_b_mux_sel_o = `OP_B_IMM;
                e.alu_operator_o     = `ALU_ADD;
                e.imm_b_mux_sel_o    = jump_mux ? `IMMB_UJ : `IMMB_PCINCR;
                we                   = !jump_mux;
            end
            `OPCODE_JALR: begin
                jmp = 1;
                e.alu_op_b_mux_sel_o = `OP_B_IMM;
                e.alu_operator_o     = `ALU_ADD;
                if (jump_mux) begin
                    e.alu_op_a_mux_sel_o = `OP_A_REGA_OR_FWD;
                    e.imm_b_mux_sel_o    = `IMMB_I;
                end else begin
                    e.alu_op_a_mux_sel_o = `OP_A_CURRPC;
                    e.imm_b_mux_sel_o    = `IMMB_PCINCR;
                    we = 1;
                end
                if (f3 != 3'b000) begin
                    jmp = 0; we = 0;
                    e.illegal_insn_o = 1;
                end
            end
            `OPCODE_BRANCH: begin
                br = 1;
                if (branch_mux) begin
                    case (f3)
                        3'b000:  e.alu_operator_o = `ALU_EQ;
                        3'b001:  e.alu_operator_o = `ALU_NE;
                        3'b100:  e.alu_operator_o = `ALU_LTS;
                        3'b101:  e.alu_operator_o = `ALU_GES;
                        3'b110:  e.alu_operator_o = `ALU_LTU;
                        3'b111:  e.alu_operator_o = `ALU_GEU;
                        default: e.illegal_insn_o = 1;
                    endcase
                end else begin
                    e.alu_op_a_mux_sel_o = `OP_A_CURRPC;
                    e.alu_op_b_mux_sel_o = `OP_B_IMM;
                    e.imm_b_mux_sel_o    = `IMMB_SB;
                    e.alu_operator_o     = `ALU_ADD;
                end
            end
            `OPCODE_STORE: begin
                req = 1;
                e.data_we_o      = 1;
                e.alu_operator_o = `ALU_ADD;
                if (!f3[2]) begin
                    e.imm_b_mux_sel_o    = `IMMB_S;
                    e.alu_op_b_mux_sel_o = `OP_B_IMM;
                end
                case (f3[1:0])
                    2'b00: e.data_type_o = 2'b10;
                    2'b01: e.data_type_o = 2'b01;
                    2'b10: e.data_type_o = 2'b00;
                    default: ;
                endcase
                if (f3[2] || f3[1:0] == 2'b11) begin
                    req = 0;
                    e.data_we_o      = 0;
                    e.illegal_insn_o = 1;
                end
            end
            `OPCODE_LOAD: begin
                req = 1; we = 1;
                e.alu_operator_o        = `ALU_ADD;
                e.alu_op_b_mux_sel_o    = `OP_B_IMM;
                e.imm_b_mux_sel_o       = `IMMB_I;
                e.data_sign_extension_o = !f3[2];
                case (f3[1:0])
                    2'b00:   e.data_type_o = 2'b10;
                    2'b01:   e.data_type_o = 2'b01;
                    default: e.data_type_o = 2'b00;
                endcase
                if (f3 == 3'b111) begin
                    e.alu_op_b_mux_sel_o    = `OP_B_REGB_OR_FWD;
                    e.data_sign_extension_o = !ins[30];
                    case (f7)
                        7'b000_0000, 7'b010_0000: e.data_type_o = 2'b10;
                        7'b000_1000, 7'b010_1000: e.data_type_o = 2'b01;
                        7'b001_0000:              e.data_type_o = 2'b00;
                        default:                  e.illegal_insn_o = 1;
                    endcase
                end
                if (f3 == 3'b110) e.data_load_event_o = 1;
                if (f3 == 3'b011) e.illegal_insn_o    = 1;
            end
            `OPCODE_LUI: begin
                e.alu_op_a_mux_sel_o = `OP_A_IMM;
                e.alu_op_b_mux_sel_o = `OP_B_IMM;
                e.imm_a_mux_sel_o    = `IMMA_ZERO;
                e.imm_b_mux_sel_o    = `IMMB_U;
                e.alu_operator_o     = `ALU_ADD;
                we = 1;
            end
            `OPCODE_AUIPC: begin
                e.alu_op_a_mux_sel_o = `OP_A_CURRPC;
                e.alu_op_b_mux_sel_o = `OP_B_IMM;
                e.imm_b_mux_sel_o    = `IMMB_U;
                e.alu_operator_o     = `ALU_ADD;
                we = 1;
            end
            `OPCODE_OPIMM: begin
                e.alu_op_b_mux_sel_o = `OP_B_IMM;
                e.imm_b_mux_sel_o    = `IMMB_I;
                we = 1;
                case (f3)
                    3'b000: e.alu_operator_o = `ALU_ADD;
                    3'b010: e.alu_operator_o = `ALU_SLTS;
                    3'b011: e.alu_operator_o = `ALU_SLTU;
                    3'b100: e.alu_operator_o = `ALU_XOR;
                    3'b110: e.alu_operator_o = `ALU_OR;
                    3'b111: e.alu_operator_o = `ALU_AND;
                    3'b001: begin
                        e.alu_operator_o = `ALU_SLL;
                        if (f7 != 7'b000_0000) e.illegal_insn_o = 1;
                    end
                    3'b101: begin
                        if      (f7 == 7'b000_0000) e.alu_operator_o = `ALU_SRL;
                        else if (f7 == 7'b010_0000) e.alu_operator_o = `ALU_SRA;
                        else                        e.illegal_insn_o = 1;
                    end
                endcase
            end
            `OPCODE_OP: begin
                we = 1;
                case ({f7, f3})
                    {7'b000_0000, 3'b000}: e.alu_operator_o = `ALU_ADD;
                    {7'b010_0000, 3'b000}: e.alu_operator_o = `ALU_SUB;
                    {7'b000_0000, 3'b010}: e.alu_operator_o = `ALU_SLTS;
                    {7'b000_0000, 3'b011}: e.alu_operator_o = `ALU_SLTU;
                    {7'b000_0000, 3'b100}: e.alu_operator_o = `ALU_XOR;
                    {7'b000_0000, 3'b110}: e.alu_operator_o = `ALU_OR;
                    {7'b000_0000, 3'b111}: e.alu_operator_o = `ALU_AND;
                    {7'b000_0000, 3'b001}: e.alu_operator_o = `ALU_SLL;
                    {7'b000_0000, 3'b101}: e.alu_operator_o = `ALU_SRL;
                    {7'b010_0000, 3'b101}: e.alu_operator_o = `ALU_SRA;
                    default:               e.illegal_insn_o = 1;
                endcase
            end
            `OPCODE_SYSTEM: begin
                if (f3 == 3'b000) begin
                    case (imm12)
                        12'h000: e.ecall_insn_o   = 1;
                        12'h001: e.ebrk_insn_o    = 1;
                        12'h302: e.mret_insn_o    = 1;
                        12'h105: e.pipe_flush_o   = 1;
                        default: e.illegal_insn_o = 1;
                    endcase
                end else begin
                    e.csr_access_o       = 1;
                    we = 1;
                    e.alu_op_b_mux_sel_o = `OP_B_IMM;
                    e.imm_a_mux_sel_o    = `IMMA_Z;
                    e.imm_b_mux_sel_o    = `IMMB_I;
                    e.alu_op_a_mux_sel_o = f3[2] ? `OP_A_IMM : `OP_A_REGA_OR_FWD;
                    case (f3[1:0])
                        2'b01:   csr_op = `CSR_OP_WRITE;
                        2'b10:   csr_op = `CSR_OP_SET;
                        2'b11:   csr_op = `CSR_OP_CLEAR;
                        default: e.illegal_insn_o = 1;
                    endcase
                    if (!e.illegal_insn_o && imm12 == 12'h300)
                        e.csr_status_o = 1;
                end
            end
            default: e.illegal_insn_o = 1;
        endcase

        if (illegal_c)
            e.illegal_insn_o = 1;

        if (misaligned) begin
            e.alu_op_a_mux_sel_o = `OP_A_REGA_OR_FWD;
            e.alu_op_b_mux_sel_o = `OP_B_IMM;
            e.imm_b_mux_sel_o    = `IMMB_PCINCR;
            we = 0;
        end

        d_alu_operator_o        = e.alu_operator_o;
        d_alu_op_a_mux_sel_o    = e.alu_op_a_mux_sel_o;
        d_alu_op_b_mux_sel_o    = e.alu_op_b_mux_sel_o;
        d_imm_a_mux_sel_o       = e.imm_a_mux_sel_o;
        d_imm_b_mux_sel_o       = e.imm_b_mux_sel_o;
        d_csr_access_o          = e.csr_access_o;
        d_csr_status_o          = e.csr_status_o;
        d_data_we_o             = e.data_we_o;
        d_data_type_o           = e.data_type_o;
        d_data_sign_extension_o = e.data_sign_extension_o;
        d_data_reg_offset_o     = e.data_reg_offset_o;
        d_data_load_event_o     = e.data_load_event_o;
        d_illegal_insn_o        = e.illegal_insn_o;
        d_ebrk_insn_o           = e.ebrk_insn_o;
        d_mret_insn_o           = e.mret_insn_o;
        d_ecall_insn_o          = e.ecall_insn_o;
        d_pipe_flush_o          = e.pipe_flush_o;
        d_regfile_we_o          = deassert_we ? 1'b0         : we;
        d_data_req_o            = deassert_we ? 1'b0         : req;
        d_csr_op_o              = deassert_we ? `CSR_OP_NONE : csr_op;
        d_jump_in_id_o          = deassert_we ? 1'b0         : jmp;
        d_branch_in_id_o        = deassert_we ? 1'b0         : br;
    endfunction

    function logic [31:0] imm_b(Id_Transaction t, logic [3:0] sel);
        logic [31:0] i;
        i = t.instr_rdata_i;
        case (sel)
            `IMMB_I:      return {{20{i[31]}}, i[31:20]};
            `IMMB_S:      return {{20{i[31]}}, i[31:25], i[11:7]};
            `IMMB_U:      return {i[31:12], 12'b0};
            `IMMB_PCINCR: return (t.is_compressed_i && !t.data_misaligned_i) ? 32'h2 : 32'h4;
            `IMMB_S2:     return {27'b0, i[24:20]};
            `IMMB_BI:     return {{27{i[24]}}, i[24:20]};
            `IMMB_S3:     return {27'b0, i[29:25]};
            `IMMB_VS:     return {{26{i[24]}}, i[24:20], i[25]};
            `IMMB_VU:     return {26'b0, i[24:20], i[25]};
            `IMMB_UJ:     return {{12{i[31]}}, i[19:12], i[20], i[30:21], 1'b0};
            `IMMB_SB:     return {{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0};
            default:      return {{20{i[31]}}, i[31:20]};
        endcase
    endfunction

    task run();
        Id_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Id_Transaction t);
        string       diff;
        logic        idle;
        logic [4:0]  rs1, rs2, rd, raddr_b;
        logic [31:0] rs1v, rs2v, fw_a, op_a, op_b, wdata;
        logic        rf_we, sel_lsu, load_stall, branch_stall, jump_stall, branch_set_n, jump_set, perf_branch, ns;
        logic        e_ready;
        diff = "";

        if (t.dbg_wb_cs !== wb_q) begin
            diff = {diff, $sformatf(" wb_state exp=%b got=%b", wb_q, t.dbg_wb_cs)};
            wb_q = t.dbg_wb_cs;
        end
        idle = (wb_q == 1'b0);

        decode(t.instr_rdata_i, !t.is_decoding_o, t.data_misaligned_i, idle, idle, t.illegal_c_insn_i);
        decode(t.instr_rdata_i, !t.is_decoding_o || d_illegal_insn_o, t.data_misaligned_i, idle, idle, t.illegal_c_insn_i);

        rs1     = t.instr_rdata_i[19:15];
        rs2     = t.instr_rdata_i[24:20];
        rd      = t.instr_rdata_i[11:7];
        raddr_b = t.dbg_reg_rreq_i ? t.dbg_reg_raddr_i : rs2;
        rs1v    = rf[rs1];
        rs2v    = rf[raddr_b];
        fw_a    = t.data_misaligned_i ? t.misaligned_addr_i : rs1v;
        case (d_alu_op_a_mux_sel_o)
            `OP_A_CURRPC: op_a = t.pc_id_i;
            `OP_A_IMM:    op_a = (d_imm_a_mux_sel_o == `IMMA_Z) ? {27'b0, rs1} : 32'h0;
            default:      op_a = fw_a;
        endcase
        op_b = (d_alu_op_b_mux_sel_o == `OP_B_IMM) ? imm_b(t, d_imm_b_mux_sel_o) : rs2v;

        rf_we = d_regfile_we_o; load_stall = 0; branch_stall = 0; jump_stall = 0; sel_lsu = 0;
        branch_set_n = 0; jump_set = 0; perf_branch = 0; ns = wb_q;
        if (idle) begin
            if (d_data_req_o) begin
                rf_we = 0; ns = 1'b1; load_stall = 1;
            end else if (d_branch_in_id_o) begin
                ns = t.branch_decision_i; branch_stall = t.branch_decision_i;
                branch_set_n = t.branch_decision_i; perf_branch = 1;
            end else if (d_jump_in_id_o) begin
                rf_we = 0; ns = 1'b1; jump_stall = 1; jump_set = 1;
            end
        end else begin
            if (t.ex_ready_i) begin
                ns = 1'b0; sel_lsu = d_data_req_o;
            end else begin
                rf_we = 0;
                if (d_data_req_o) load_stall = 1;
            end
        end
        e_ready = !(load_stall || branch_stall || jump_stall);
        if (!e_ready) stalls++;

        `define ID_CMP(sig, exp) if (t.sig !== exp) diff = {diff, $sformatf(" %s exp=%0h got=%0h", `"sig`", exp, t.sig)};
        `ID_CMP(id_ready_o, e_ready)
        `ID_CMP(id_valid_o, (!t.dbg_halt_id && e_ready))
        `ID_CMP(clear_instr_valid_o, (e_ready || t.dbg_halt_id))
        `ID_CMP(perf_branch_o, perf_branch)
        `ID_CMP(dbg_reg_rdata_o, rs2v)
        `ID_CMP(data_wdata_ex_o, rs2v)
        if (t.instr_valid_i) begin
            decode_count++;
            `ID_CMP(alu_operator_ex_o, d_alu_operator_o)
            `ID_CMP(alu_operand_a_ex_o, op_a)
            `ID_CMP(alu_operand_b_ex_o, op_b)
            `ID_CMP(csr_access_ex_o, d_csr_access_o)
            `ID_CMP(csr_op_ex_o, d_csr_op_o)
            `ID_CMP(data_req_ex_o, d_data_req_o)
            `ID_CMP(data_we_ex_o, d_data_we_o)
            `ID_CMP(data_type_ex_o, d_data_type_o)
            `ID_CMP(data_sign_ext_ex_o, d_data_sign_extension_o)
            `ID_CMP(data_reg_offset_ex_o, d_data_reg_offset_o)
            `ID_CMP(data_load_event_ex_o, d_data_load_event_o)
            `ID_CMP(branch_in_ex_o, d_branch_in_id_o)
        end
        if (t.is_decoding_o) begin
            if (branch_set_q) begin
                `ID_CMP(pc_set_o, 1'b1)
                `ID_CMP(pc_mux_o, `PC_JUMP)
                `ID_CMP(perf_tbranch_o, 1'b1)
            end else if (jump_set) begin
                `ID_CMP(pc_set_o, 1'b1)
                `ID_CMP(pc_mux_o, `PC_JUMP)
                `ID_CMP(perf_jump_o, 1'b1)
            end
        end
        `undef ID_CMP
        if (t.dbg_reg_rreq_i) dbg_reads++;

        if (t.dbg_reg_wreq_i) begin
            if (t.dbg_reg_waddr_i != 5'd0) rf[t.dbg_reg_waddr_i] = t.dbg_reg_wdata_i;
        end else if (rf_we && rd != 5'd0) begin
            wdata = sel_lsu ? t.regfile_wdata_lsu_i : (d_csr_access_o ? t.csr_rdata_i : t.regfile_wdata_ex_i);
            rf[rd] = wdata;
            write_count++;
        end
        wb_q         = ns;
        branch_set_q = branch_set_n;

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH instr=%h iv=%b dec=%b wb=%b exrdy=%b :%s",
                   t.instr_rdata_i, t.instr_valid_i, t.is_decoding_o, t.dbg_wb_cs, t.ex_ready_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d decoded=%0d rf_writes=%0d dbg_reads=%0d stall_cycles=%0d",
                 total_count, pass_count, fail_count, decode_count, write_count, dbg_reads, stalls);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0 && write_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
