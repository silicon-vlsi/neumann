class Decoder_Scoreboard;
    mailbox #(Decoder_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;

    function new(mailbox #(Decoder_Transaction) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    task run();
        Decoder_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function Decoder_Transaction predict(Decoder_Transaction tx);
        Decoder_Transaction e;
        logic [31:0] ins;
        logic [6:0]  opcode;
        logic [2:0]  f3;
        logic [6:0]  f7;
        logic [11:0] imm12;
        logic        we, req, jmp, br;
        logic [1:0]  csr_op;

        e      = tx.do_copy();
        ins    = tx.instr_rdata_i;
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
                e.imm_b_mux_sel_o    = tx.jump_mux_i ? `IMMB_UJ : `IMMB_PCINCR;
                we                   = !tx.jump_mux_i;
            end
            `OPCODE_JALR: begin
                jmp = 1;
                e.alu_op_b_mux_sel_o = `OP_B_IMM;
                e.alu_operator_o     = `ALU_ADD;
                if (tx.jump_mux_i) begin
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
                if (tx.branch_mux_i) begin
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

        if (tx.illegal_c_insn_i)
            e.illegal_insn_o = 1;

        if (tx.data_misaligned_i) begin
            e.alu_op_a_mux_sel_o = `OP_A_REGA_OR_FWD;
            e.alu_op_b_mux_sel_o = `OP_B_IMM;
            e.imm_b_mux_sel_o    = `IMMB_PCINCR;
            we = 0;
        end

        e.regfile_we_o   = tx.deassert_we_i ? 1'b0         : we;
        e.data_req_o     = tx.deassert_we_i ? 1'b0         : req;
        e.csr_op_o       = tx.deassert_we_i ? `CSR_OP_NONE : csr_op;
        e.jump_in_id_o   = tx.deassert_we_i ? 1'b0         : jmp;
        e.branch_in_id_o = tx.deassert_we_i ? 1'b0         : br;
        return e;
    endfunction

    function void check(Decoder_Transaction tx);
        Decoder_Transaction e;
        string diff = "";
        e = predict(tx);

        `define DEC_CMP(f) if (tx.f !== e.f) diff = {diff, $sformatf(" %s(exp=%0h got=%0h)", `"f`", e.f, tx.f)};
        `DEC_CMP(illegal_insn_o)
        `DEC_CMP(ebrk_insn_o)
        `DEC_CMP(mret_insn_o)
        `DEC_CMP(ecall_insn_o)
        `DEC_CMP(pipe_flush_o)
        `DEC_CMP(alu_operator_o)
        `DEC_CMP(alu_op_a_mux_sel_o)
        `DEC_CMP(alu_op_b_mux_sel_o)
        `DEC_CMP(imm_a_mux_sel_o)
        `DEC_CMP(imm_b_mux_sel_o)
        `DEC_CMP(regfile_we_o)
        `DEC_CMP(csr_access_o)
        `DEC_CMP(csr_op_o)
        `DEC_CMP(csr_status_o)
        `DEC_CMP(data_req_o)
        `DEC_CMP(data_we_o)
        `DEC_CMP(data_type_o)
        `DEC_CMP(data_sign_extension_o)
        `DEC_CMP(data_reg_offset_o)
        `DEC_CMP(data_load_event_o)
        `DEC_CMP(jump_in_id_o)
        `DEC_CMP(branch_in_id_o)
        `undef DEC_CMP

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH instr=%h dwe=%b mis=%b bmux=%b jmux=%b ic=%b :%s",
                   tx.instr_rdata_i, tx.deassert_we_i, tx.data_misaligned_i,
                   tx.branch_mux_i, tx.jump_mux_i, tx.illegal_c_insn_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d",
                 total_count, pass_count, fail_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
