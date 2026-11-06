`include "rv32i_defines.vh"
module Decoder_Assertions (
    input logic                     clk,
    input logic                     deassert_we_i,
    input logic                     data_misaligned_i,
    input logic                     branch_mux_i,
    input logic                     jump_mux_i,
    input logic [31:0]              instr_rdata_i,
    input logic                     illegal_c_insn_i,
    input logic                     illegal_insn_o,
    input logic                     ebrk_insn_o,
    input logic                     mret_insn_o,
    input logic                     ecall_insn_o,
    input logic                     pipe_flush_o,
    input logic [`ALU_OP_WIDTH-1:0] alu_operator_o,
    input logic [2:0]               alu_op_a_mux_sel_o,
    input logic [2:0]               alu_op_b_mux_sel_o,
    input logic                     imm_a_mux_sel_o,
    input logic [3:0]               imm_b_mux_sel_o,
    input logic                     regfile_we_o,
    input logic                     csr_access_o,
    input logic [1:0]               csr_op_o,
    input logic                     csr_status_o,
    input logic                     data_req_o,
    input logic                     data_we_o,
    input logic [1:0]               data_type_o,
    input logic                     data_sign_extension_o,
    input logic [1:0]               data_reg_offset_o,
    input logic                     data_load_event_o,
    input logic                     jump_in_id_o,
    input logic                     branch_in_id_o
);

    wire [6:0] opcode = instr_rdata_i[6:0];
    wire [2:0] funct3 = instr_rdata_i[14:12];

    wire inputs_known = !$isunknown({deassert_we_i, data_misaligned_i, branch_mux_i,
                                     jump_mux_i, instr_rdata_i, illegal_c_insn_i});

    wire opcode_known = opcode inside {`OPCODE_LUI, `OPCODE_AUIPC, `OPCODE_JAL, `OPCODE_JALR,
                                       `OPCODE_BRANCH, `OPCODE_LOAD, `OPCODE_STORE,
                                       `OPCODE_OPIMM, `OPCODE_OP, `OPCODE_SYSTEM};

    property p_no_x_out;
        @(negedge clk) disable iff (!inputs_known)
        !$isunknown({illegal_insn_o, ebrk_insn_o, mret_insn_o, ecall_insn_o, pipe_flush_o,
                     alu_operator_o, alu_op_a_mux_sel_o, alu_op_b_mux_sel_o,
                     imm_a_mux_sel_o, imm_b_mux_sel_o, regfile_we_o,
                     csr_access_o, csr_op_o, csr_status_o,
                     data_req_o, data_we_o, data_type_o, data_sign_extension_o,
                     data_reg_offset_o, data_load_event_o, jump_in_id_o, branch_in_id_o});
    endproperty
    a_no_x_out : assert property (p_no_x_out)
        else $error("DECODER: X/Z on outputs for instr=%h", instr_rdata_i);

    property p_sys_onehot;
        @(negedge clk) disable iff (!inputs_known)
        $onehot0({ebrk_insn_o, mret_insn_o, ecall_insn_o, pipe_flush_o});
    endproperty
    a_sys_onehot : assert property (p_sys_onehot)
        else $error("DECODER: more than one of ebrk/mret/ecall/wfi set");

    property p_reg_offset_zero;
        @(negedge clk) disable iff (!inputs_known)
        data_reg_offset_o == 2'b00;
    endproperty
    a_reg_offset_zero : assert property (p_reg_offset_zero)
        else $error("DECODER: data_reg_offset_o=%b, RV32I never sets it", data_reg_offset_o);

    property p_deassert;
        @(negedge clk) disable iff (!inputs_known)
        deassert_we_i |-> !regfile_we_o && !data_req_o && (csr_op_o == `CSR_OP_NONE)
                          && !jump_in_id_o && !branch_in_id_o;
    endproperty
    a_deassert : assert property (p_deassert)
        else $error("DECODER: write/request not gated by deassert_we_i");

    property p_illegal_c;
        @(negedge clk) disable iff (!inputs_known)
        illegal_c_insn_i |-> illegal_insn_o;
    endproperty
    a_illegal_c : assert property (p_illegal_c)
        else $error("DECODER: illegal_c_insn_i did not raise illegal_insn_o");

    property p_misaligned;
        @(negedge clk) disable iff (!inputs_known)
        data_misaligned_i |-> !regfile_we_o
                              && (alu_op_a_mux_sel_o == `OP_A_REGA_OR_FWD)
                              && (alu_op_b_mux_sel_o == `OP_B_IMM)
                              && (imm_b_mux_sel_o    == `IMMB_PCINCR);
    endproperty
    a_misaligned : assert property (p_misaligned)
        else $error("DECODER: misaligned override not applied");

    property p_unknown_opcode;
        @(negedge clk) disable iff (!inputs_known)
        !opcode_known |-> illegal_insn_o;
    endproperty
    a_unknown_opcode : assert property (p_unknown_opcode)
        else $error("DECODER: opcode %h not flagged illegal", opcode);

    property p_sys_only;
        @(negedge clk) disable iff (!inputs_known)
        (ebrk_insn_o || mret_insn_o || ecall_insn_o || pipe_flush_o)
            |-> (opcode == `OPCODE_SYSTEM) && (funct3 == 3'b000);
    endproperty
    a_sys_only : assert property (p_sys_only)
        else $error("DECODER: system flag set for non-SYSTEM instr=%h", instr_rdata_i);

    property p_csr_only;
        @(negedge clk) disable iff (!inputs_known)
        csr_access_o |-> (opcode == `OPCODE_SYSTEM) && (funct3 != 3'b000);
    endproperty
    a_csr_only : assert property (p_csr_only)
        else $error("DECODER: csr_access_o for non-CSR instr=%h", instr_rdata_i);

    property p_csr_status;
        @(negedge clk) disable iff (!inputs_known)
        csr_status_o |-> csr_access_o && (instr_rdata_i[31:20] == 12'h300) && (funct3[1:0] != 2'b00);
    endproperty
    a_csr_status : assert property (p_csr_status)
        else $error("DECODER: csr_status_o without a legal mstatus access");

    property p_mem_only;
        @(negedge clk) disable iff (!inputs_known)
        data_req_o |-> opcode inside {`OPCODE_LOAD, `OPCODE_STORE};
    endproperty
    a_mem_only : assert property (p_mem_only)
        else $error("DECODER: data_req_o for non load/store instr=%h", instr_rdata_i);

    property p_store_only;
        @(negedge clk) disable iff (!inputs_known)
        data_we_o |-> (opcode == `OPCODE_STORE) && !funct3[2] && (funct3[1:0] != 2'b11);
    endproperty
    a_store_only : assert property (p_store_only)
        else $error("DECODER: data_we_o for non-store / illegal store instr=%h", instr_rdata_i);

    property p_load_event;
        @(negedge clk) disable iff (!inputs_known)
        data_load_event_o |-> (opcode == `OPCODE_LOAD) && (funct3 == 3'b110);
    endproperty
    a_load_event : assert property (p_load_event)
        else $error("DECODER: data_load_event_o for instr=%h", instr_rdata_i);

    property p_jump_only;
        @(negedge clk) disable iff (!inputs_known)
        jump_in_id_o |-> opcode inside {`OPCODE_JAL, `OPCODE_JALR};
    endproperty
    a_jump_only : assert property (p_jump_only)
        else $error("DECODER: jump_in_id_o for instr=%h", instr_rdata_i);

    property p_branch_only;
        @(negedge clk) disable iff (!inputs_known)
        branch_in_id_o |-> (opcode == `OPCODE_BRANCH);
    endproperty
    a_branch_only : assert property (p_branch_only)
        else $error("DECODER: branch_in_id_o for instr=%h", instr_rdata_i);

    property p_jal_jump;
        @(negedge clk) disable iff (!inputs_known)
        (opcode == `OPCODE_JAL) && !deassert_we_i |-> jump_in_id_o;
    endproperty
    a_jal_jump : assert property (p_jal_jump)
        else $error("DECODER: JAL without jump_in_id_o");

    property p_branch_target;
        @(negedge clk) disable iff (!inputs_known)
        (opcode == `OPCODE_BRANCH) && !branch_mux_i && !data_misaligned_i
            |-> (alu_operator_o == `ALU_ADD) && (imm_b_mux_sel_o == `IMMB_SB);
    endproperty
    a_branch_target : assert property (p_branch_target)
        else $error("DECODER: branch target phase not PC + SB-imm");

    c_lui      : cover property (@(negedge clk) opcode == `OPCODE_LUI    && !illegal_insn_o);
    c_auipc    : cover property (@(negedge clk) opcode == `OPCODE_AUIPC  && !illegal_insn_o);
    c_jal      : cover property (@(negedge clk) opcode == `OPCODE_JAL    && jump_in_id_o);
    c_jalr     : cover property (@(negedge clk) opcode == `OPCODE_JALR   && jump_in_id_o);
    c_branch   : cover property (@(negedge clk) opcode == `OPCODE_BRANCH && branch_in_id_o);
    c_load     : cover property (@(negedge clk) opcode == `OPCODE_LOAD   && data_req_o);
    c_store    : cover property (@(negedge clk) data_req_o && data_we_o);
    c_csr      : cover property (@(negedge clk) csr_access_o && csr_op_o != `CSR_OP_NONE);
    c_mstatus  : cover property (@(negedge clk) csr_status_o);
    c_ecall    : cover property (@(negedge clk) ecall_insn_o);
    c_ebreak   : cover property (@(negedge clk) ebrk_insn_o);
    c_mret     : cover property (@(negedge clk) mret_insn_o);
    c_wfi      : cover property (@(negedge clk) pipe_flush_o);
    c_illegal  : cover property (@(negedge clk) illegal_insn_o && !illegal_c_insn_i);
    c_ill_c    : cover property (@(negedge clk) illegal_c_insn_i && opcode_known);
    c_load_ev  : cover property (@(negedge clk) data_load_event_o);
    c_stall_j  : cover property (@(negedge clk) deassert_we_i && opcode == `OPCODE_JAL);
    c_mis_load : cover property (@(negedge clk) data_misaligned_i && opcode == `OPCODE_LOAD);

endmodule

bind rv32i_decoder Decoder_Assertions u_assert (
    .clk                   (Decoder_tb_top.clk),
    .deassert_we_i         (deassert_we_i),
    .data_misaligned_i     (data_misaligned_i),
    .branch_mux_i          (branch_mux_i),
    .jump_mux_i            (jump_mux_i),
    .instr_rdata_i         (instr_rdata_i),
    .illegal_c_insn_i      (illegal_c_insn_i),
    .illegal_insn_o        (illegal_insn_o),
    .ebrk_insn_o           (ebrk_insn_o),
    .mret_insn_o           (mret_insn_o),
    .ecall_insn_o          (ecall_insn_o),
    .pipe_flush_o          (pipe_flush_o),
    .alu_operator_o        (alu_operator_o),
    .alu_op_a_mux_sel_o    (alu_op_a_mux_sel_o),
    .alu_op_b_mux_sel_o    (alu_op_b_mux_sel_o),
    .imm_a_mux_sel_o       (imm_a_mux_sel_o),
    .imm_b_mux_sel_o       (imm_b_mux_sel_o),
    .regfile_we_o          (regfile_we_o),
    .csr_access_o          (csr_access_o),
    .csr_op_o              (csr_op_o),
    .csr_status_o          (csr_status_o),
    .data_req_o            (data_req_o),
    .data_we_o             (data_we_o),
    .data_type_o           (data_type_o),
    .data_sign_extension_o (data_sign_extension_o),
    .data_reg_offset_o     (data_reg_offset_o),
    .data_load_event_o     (data_load_event_o),
    .jump_in_id_o          (jump_in_id_o),
    .branch_in_id_o        (branch_in_id_o)
);
