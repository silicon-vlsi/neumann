`include "rv32i_defines.vh"
class Id_Transaction;
    rand logic [31:0] next_instr;
    rand logic fetch_valid;
    rand logic branch_decision_i;
    rand logic ex_ready_i;
    rand logic data_misaligned_i;
    rand logic [31:0] misaligned_addr_i;
    rand logic dbg_reg_rreq_i;
    rand logic [4:0] dbg_reg_raddr_i;
    rand logic dbg_reg_wreq_i;
    rand logic [4:0] dbg_reg_waddr_i;
    rand logic [31:0] dbg_reg_wdata_i;
    rand logic [31:0] regfile_wdata_lsu_i;
    rand logic [31:0] regfile_wdata_ex_i;
    rand logic [31:0] csr_rdata_i;
    rand int unsigned kind;

    logic rst_n;
    logic test_en_i;
    logic fetch_enable_i;
    logic instr_valid_i;
    logic [31:0] instr_rdata_i;
    logic illegal_c_insn_i;
    logic is_compressed_i;
    logic [31:0] pc_id_i;
    logic irq_i;
    logic [4:0] irq_id_i;
    logic m_irq_enable_i;
    logic lsu_load_err_i;
    logic lsu_store_err_i;
    logic [`DBG_SETS_W-1:0] dbg_settings_i;
    logic dbg_req_i;
    logic dbg_stall_i;
    logic dbg_jump_req_i;
    logic ctrl_busy_o;
    logic core_ctrl_firstfetch_o;
    logic is_decoding_o;
    logic instr_req_o;
    logic branch_in_ex_o;
    logic clear_instr_valid_o;
    logic pc_set_o;
    logic [2:0] pc_mux_o;
    logic [1:0] exc_pc_mux_o;
    logic halt_if_o;
    logic id_ready_o;
    logic id_valid_o;
    logic [`ALU_OP_WIDTH-1:0] alu_operator_ex_o;
    logic [31:0] alu_operand_a_ex_o;
    logic [31:0] alu_operand_b_ex_o;
    logic csr_access_ex_o;
    logic [1:0] csr_op_ex_o;
    logic [5:0] csr_cause_o;
    logic csr_save_if_o;
    logic csr_save_id_o;
    logic csr_restore_mret_id_o;
    logic csr_save_cause_o;
    logic data_req_ex_o;
    logic data_we_ex_o;
    logic [1:0] data_type_ex_o;
    logic data_sign_ext_ex_o;
    logic [1:0] data_reg_offset_ex_o;
    logic data_load_event_ex_o;
    logic [31:0] data_wdata_ex_o;
    logic irq_ack_o;
    logic [4:0] irq_id_o;
    logic [5:0] exc_cause_o;
    logic dbg_ack_o;
    logic dbg_trap_o;
    logic [31:0] dbg_reg_rdata_o;
    logic perf_jump_o;
    logic perf_branch_o;
    logic perf_tbranch_o;
    logic dbg_wb_cs;
    logic dbg_halt_id;

    constraint c_kind
    {
        kind dist {[0:9] :/ 95, [10:11] :/ 5};
    }

    constraint c_env
    {
        fetch_valid dist {1 := 85, 0 := 15};
        branch_decision_i dist {1 := 50, 0 := 50};
        ex_ready_i dist {1 := 70, 0 := 30};
        data_misaligned_i dist {1 := 3, 0 := 97};
        dbg_reg_rreq_i dist {1 := 10, 0 := 90};
        dbg_reg_wreq_i dist {1 := 3, 0 := 97};
    }

    static function logic [31:0] make_instr(int unsigned kind);
        logic [4:0]  rd, rs1, rs2;
        logic [2:0]  f3;
        logic [11:0] imm;
        logic [31:0] r;
        logic [2:0]  ops3[$];
        r   = $urandom();
        rd  = $urandom();
        rs1 = $urandom();
        rs2 = $urandom();
        imm = $urandom();
        f3  = $urandom();
        case (kind % 12)
            0: begin
                ops3 = '{3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111};
                f3 = ops3[$urandom_range(0, 7)];
                if (f3 == 3'b000 || f3 == 3'b101)
                    return {($urandom_range(0, 1) ? 7'b0100000 : 7'b0000000), rs2, rs1, f3, rd, `OPCODE_OP};
                return {7'b0000000, rs2, rs1, f3, rd, `OPCODE_OP};
            end
            1: begin
                if (f3 == 3'b001) return {7'b0000000, imm[4:0], rs1, f3, rd, `OPCODE_OPIMM};
                if (f3 == 3'b101) return {($urandom_range(0, 1) ? 7'b0100000 : 7'b0000000), imm[4:0], rs1, f3, rd, `OPCODE_OPIMM};
                return {imm, rs1, f3, rd, `OPCODE_OPIMM};
            end
            2: return {r[31:12], rd, `OPCODE_LUI};
            3: return {r[31:12], rd, `OPCODE_AUIPC};
            4: begin
                ops3 = '{3'b000, 3'b001, 3'b010, 3'b100, 3'b101};
                return {imm, rs1, ops3[$urandom_range(0, 4)], rd, `OPCODE_LOAD};
            end
            5: return {imm[11:5], rs2, rs1, 1'b0, f3[1:0] == 2'b11 ? 2'b10 : f3[1:0], imm[4:0], `OPCODE_STORE};
            6: begin
                ops3 = '{3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};
                return {imm[11:5], rs2, rs1, ops3[$urandom_range(0, 5)], imm[4:0], `OPCODE_BRANCH};
            end
            7: return {r[31:12], rd, `OPCODE_JAL};
            8: return {imm, rs1, 3'b000, rd, `OPCODE_JALR};
            9: begin
                ops3 = '{3'b001, 3'b010, 3'b011, 3'b101, 3'b110, 3'b111};
                return {($urandom_range(0, 3) == 0) ? 12'h300 : imm, rs1, ops3[$urandom_range(0, 5)], rd, `OPCODE_SYSTEM};
            end
            10: begin
                ops3 = '{3'b000, 3'b001, 3'b010, 3'b011};
                case (ops3[$urandom_range(0, 3)])
                    3'b000:  return 32'h0000_0073;
                    3'b001:  return 32'h0010_0073;
                    3'b010:  return 32'h3020_0073;
                    default: return 32'h1050_0073;
                endcase
            end
            default: return r;
        endcase
    endfunction

    function void display(string tag="TX");
        $display("[%s] iv=%b instr=%h pc=%h exrdy=%b bd=%b mis=%b | dec=%b rdy=%b valid=%b wb=%b op=%h a=%h b=%h req=%b pcset=%b",
                 tag, instr_valid_i, instr_rdata_i, pc_id_i, ex_ready_i, branch_decision_i, data_misaligned_i,
                 is_decoding_o, id_ready_o, id_valid_o, dbg_wb_cs, alu_operator_ex_o, alu_operand_a_ex_o, alu_operand_b_ex_o,
                 data_req_ex_o, pc_set_o);
    endfunction

    function Id_Transaction do_copy();
        Id_Transaction copy;
        copy = new();
        copy.next_instr = this.next_instr;
        copy.fetch_valid = this.fetch_valid;
        copy.branch_decision_i = this.branch_decision_i;
        copy.ex_ready_i = this.ex_ready_i;
        copy.data_misaligned_i = this.data_misaligned_i;
        copy.misaligned_addr_i = this.misaligned_addr_i;
        copy.dbg_reg_rreq_i = this.dbg_reg_rreq_i;
        copy.dbg_reg_raddr_i = this.dbg_reg_raddr_i;
        copy.dbg_reg_wreq_i = this.dbg_reg_wreq_i;
        copy.dbg_reg_waddr_i = this.dbg_reg_waddr_i;
        copy.dbg_reg_wdata_i = this.dbg_reg_wdata_i;
        copy.regfile_wdata_lsu_i = this.regfile_wdata_lsu_i;
        copy.regfile_wdata_ex_i = this.regfile_wdata_ex_i;
        copy.csr_rdata_i = this.csr_rdata_i;
        copy.kind = this.kind;
        copy.rst_n = this.rst_n;
        copy.test_en_i = this.test_en_i;
        copy.fetch_enable_i = this.fetch_enable_i;
        copy.instr_valid_i = this.instr_valid_i;
        copy.instr_rdata_i = this.instr_rdata_i;
        copy.illegal_c_insn_i = this.illegal_c_insn_i;
        copy.is_compressed_i = this.is_compressed_i;
        copy.pc_id_i = this.pc_id_i;
        copy.irq_i = this.irq_i;
        copy.irq_id_i = this.irq_id_i;
        copy.m_irq_enable_i = this.m_irq_enable_i;
        copy.lsu_load_err_i = this.lsu_load_err_i;
        copy.lsu_store_err_i = this.lsu_store_err_i;
        copy.dbg_settings_i = this.dbg_settings_i;
        copy.dbg_req_i = this.dbg_req_i;
        copy.dbg_stall_i = this.dbg_stall_i;
        copy.dbg_jump_req_i = this.dbg_jump_req_i;
        copy.ctrl_busy_o = this.ctrl_busy_o;
        copy.core_ctrl_firstfetch_o = this.core_ctrl_firstfetch_o;
        copy.is_decoding_o = this.is_decoding_o;
        copy.instr_req_o = this.instr_req_o;
        copy.branch_in_ex_o = this.branch_in_ex_o;
        copy.clear_instr_valid_o = this.clear_instr_valid_o;
        copy.pc_set_o = this.pc_set_o;
        copy.pc_mux_o = this.pc_mux_o;
        copy.exc_pc_mux_o = this.exc_pc_mux_o;
        copy.halt_if_o = this.halt_if_o;
        copy.id_ready_o = this.id_ready_o;
        copy.id_valid_o = this.id_valid_o;
        copy.alu_operator_ex_o = this.alu_operator_ex_o;
        copy.alu_operand_a_ex_o = this.alu_operand_a_ex_o;
        copy.alu_operand_b_ex_o = this.alu_operand_b_ex_o;
        copy.csr_access_ex_o = this.csr_access_ex_o;
        copy.csr_op_ex_o = this.csr_op_ex_o;
        copy.csr_cause_o = this.csr_cause_o;
        copy.csr_save_if_o = this.csr_save_if_o;
        copy.csr_save_id_o = this.csr_save_id_o;
        copy.csr_restore_mret_id_o = this.csr_restore_mret_id_o;
        copy.csr_save_cause_o = this.csr_save_cause_o;
        copy.data_req_ex_o = this.data_req_ex_o;
        copy.data_we_ex_o = this.data_we_ex_o;
        copy.data_type_ex_o = this.data_type_ex_o;
        copy.data_sign_ext_ex_o = this.data_sign_ext_ex_o;
        copy.data_reg_offset_ex_o = this.data_reg_offset_ex_o;
        copy.data_load_event_ex_o = this.data_load_event_ex_o;
        copy.data_wdata_ex_o = this.data_wdata_ex_o;
        copy.irq_ack_o = this.irq_ack_o;
        copy.irq_id_o = this.irq_id_o;
        copy.exc_cause_o = this.exc_cause_o;
        copy.dbg_ack_o = this.dbg_ack_o;
        copy.dbg_trap_o = this.dbg_trap_o;
        copy.dbg_reg_rdata_o = this.dbg_reg_rdata_o;
        copy.perf_jump_o = this.perf_jump_o;
        copy.perf_branch_o = this.perf_branch_o;
        copy.perf_tbranch_o = this.perf_tbranch_o;
        copy.dbg_wb_cs = this.dbg_wb_cs;
        copy.dbg_halt_id = this.dbg_halt_id;
        return copy;
    endfunction
endclass
