class Decoder_Transaction;
    rand logic        deassert_we_i;
    rand logic        data_misaligned_i;
    rand logic        branch_mux_i;
    rand logic        jump_mux_i;
    rand logic [31:0] instr_rdata_i;
    rand logic        illegal_c_insn_i;

    logic                     illegal_insn_o;
    logic                     ebrk_insn_o;
    logic                     mret_insn_o;
    logic                     ecall_insn_o;
    logic                     pipe_flush_o;
    logic [`ALU_OP_WIDTH-1:0] alu_operator_o;
    logic [2:0]               alu_op_a_mux_sel_o;
    logic [2:0]               alu_op_b_mux_sel_o;
    logic                     imm_a_mux_sel_o;
    logic [3:0]               imm_b_mux_sel_o;
    logic                     regfile_we_o;
    logic                     csr_access_o;
    logic [1:0]               csr_op_o;
    logic                     csr_status_o;
    logic                     data_req_o;
    logic                     data_we_o;
    logic [1:0]               data_type_o;
    logic                     data_sign_extension_o;
    logic [1:0]               data_reg_offset_o;
    logic                     data_load_event_o;
    logic                     jump_in_id_o;
    logic                     branch_in_id_o;

    constraint c_opcode
    {
        instr_rdata_i[6:0] dist {
            `OPCODE_LUI    := 8,  `OPCODE_AUIPC  := 8,
            `OPCODE_JAL    := 8,  `OPCODE_JALR   := 8,
            `OPCODE_BRANCH := 10, `OPCODE_LOAD   := 12,
            `OPCODE_STORE  := 10, `OPCODE_OPIMM  := 12,
            `OPCODE_OP     := 12, `OPCODE_SYSTEM := 10,
            `OPCODE_FENCE  := 2,  [0:127]        :/ 4
        };
    }
    constraint c_funct7
    {
        if (instr_rdata_i[6:0] != `OPCODE_SYSTEM) {
            instr_rdata_i[31:25] dist {
                7'b000_0000 := 40, 7'b010_0000 := 30,
                7'b000_1000 := 5,  7'b010_1000 := 5, 7'b001_0000 := 5,
                [0:127]     :/ 15
            };
        }
    }
    constraint c_system
    {
        if (instr_rdata_i[6:0] == `OPCODE_SYSTEM) {
            instr_rdata_i[14:12] dist {3'b000 := 40, [1:7] :/ 60};
            if (instr_rdata_i[14:12] == 3'b000)
                instr_rdata_i[31:20] dist {
                    12'h000 := 20, 12'h001 := 20, 12'h302 := 20,
                    12'h105 := 20, [0:4095] :/ 20
                };
            else
                instr_rdata_i[31:20] dist {12'h300 := 40, [0:4095] :/ 60};
        }
    }
    constraint c_ctrl
    {
        deassert_we_i     dist {1 := 10, 0 := 90};
        data_misaligned_i dist {1 := 10, 0 := 90};
        illegal_c_insn_i  dist {1 := 5,  0 := 95};
        branch_mux_i      dist {1 := 50, 0 := 50};
        jump_mux_i        dist {1 := 50, 0 := 50};
    }

    function void display(string tag="TX");
        $display("[%s] instr=%h op=%h f3=%b f7=%b dwe=%b mis=%b bmux=%b jmux=%b ic=%b | ill=%b ebrk=%b mret=%b ecall=%b wfi=%b alu=%b a=%0d b=%0d ia=%b ib=%0d we=%b csr=%b csr_op=%0d st=%b req=%b dwe_o=%b type=%0d sext=%b ev=%b jmp=%b br=%b",
                 tag, instr_rdata_i, instr_rdata_i[6:0], instr_rdata_i[14:12], instr_rdata_i[31:25],
                 deassert_we_i, data_misaligned_i, branch_mux_i, jump_mux_i, illegal_c_insn_i,
                 illegal_insn_o, ebrk_insn_o, mret_insn_o, ecall_insn_o, pipe_flush_o,
                 alu_operator_o, alu_op_a_mux_sel_o, alu_op_b_mux_sel_o, imm_a_mux_sel_o, imm_b_mux_sel_o,
                 regfile_we_o, csr_access_o, csr_op_o, csr_status_o,
                 data_req_o, data_we_o, data_type_o, data_sign_extension_o, data_load_event_o,
                 jump_in_id_o, branch_in_id_o);
    endfunction

    function Decoder_Transaction do_copy();
    Decoder_Transaction copy;
    copy = new();
    copy.deassert_we_i         = this.deassert_we_i;
    copy.data_misaligned_i     = this.data_misaligned_i;
    copy.branch_mux_i          = this.branch_mux_i;
    copy.jump_mux_i            = this.jump_mux_i;
    copy.instr_rdata_i         = this.instr_rdata_i;
    copy.illegal_c_insn_i      = this.illegal_c_insn_i;
    copy.illegal_insn_o        = this.illegal_insn_o;
    copy.ebrk_insn_o           = this.ebrk_insn_o;
    copy.mret_insn_o           = this.mret_insn_o;
    copy.ecall_insn_o          = this.ecall_insn_o;
    copy.pipe_flush_o          = this.pipe_flush_o;
    copy.alu_operator_o        = this.alu_operator_o;
    copy.alu_op_a_mux_sel_o    = this.alu_op_a_mux_sel_o;
    copy.alu_op_b_mux_sel_o    = this.alu_op_b_mux_sel_o;
    copy.imm_a_mux_sel_o       = this.imm_a_mux_sel_o;
    copy.imm_b_mux_sel_o       = this.imm_b_mux_sel_o;
    copy.regfile_we_o          = this.regfile_we_o;
    copy.csr_access_o          = this.csr_access_o;
    copy.csr_op_o              = this.csr_op_o;
    copy.csr_status_o          = this.csr_status_o;
    copy.data_req_o            = this.data_req_o;
    copy.data_we_o             = this.data_we_o;
    copy.data_type_o           = this.data_type_o;
    copy.data_sign_extension_o = this.data_sign_extension_o;
    copy.data_reg_offset_o     = this.data_reg_offset_o;
    copy.data_load_event_o     = this.data_load_event_o;
    copy.jump_in_id_o          = this.jump_in_id_o;
    copy.branch_in_id_o        = this.branch_in_id_o;
    return copy;
    endfunction
endclass
