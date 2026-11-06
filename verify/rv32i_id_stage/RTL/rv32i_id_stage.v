
`include "rv32i_defines.vh"
`define REG_S1 19:15
`define REG_S2 24:20
`define REG_D  11:07
`define S_IDLE           1'b0
`define S_WAIT_MULTICYCLE 1'b1
`define RF_LSU  1'b0
`define RF_EX   1'b1
module rv32i_id_stage
#(
  parameter DATA_WIDTH=32,
  parameter RV32E=0
)
(
  input wire clk,
  input wire rst_n,
  input wire test_en_i,
  input wire fetch_enable_i,
  output wire ctrl_busy_o,
  output wire core_ctrl_firstfetch_o,
  output wire is_decoding_o,
  input wire instr_valid_i,
  input wire [31:0] instr_rdata_i,
  output wire instr_req_o,
  output wire branch_in_ex_o,
  input wire branch_decision_i,
  output wire clear_instr_valid_o,
  output wire pc_set_o,
  output wire [2:0] pc_mux_o,
  output wire [1:0] exc_pc_mux_o,
  input wire illegal_c_insn_i,
  input wire is_compressed_i,
  input wire [31:0] pc_id_i,
  output wire halt_if_o,
  output wire id_ready_o,
  input wire ex_ready_i,
  output wire id_valid_o,
  output wire [`ALU_OP_WIDTH-1:0] alu_operator_ex_o,
  output wire [31:0] alu_operand_a_ex_o,
  output wire [31:0] alu_operand_b_ex_o,
  output wire csr_access_ex_o,
  output wire [1:0] csr_op_ex_o,
  output wire [5:0] csr_cause_o,
  output wire csr_save_if_o,
  output wire csr_save_id_o,
  output wire csr_restore_mret_id_o,
  output wire csr_save_cause_o,
  output wire data_req_ex_o,
  output wire data_we_ex_o,
  output wire [1:0] data_type_ex_o,
  output wire data_sign_ext_ex_o,
  output wire [1:0] data_reg_offset_ex_o,
  output wire data_load_event_ex_o,
  output wire [31:0] data_wdata_ex_o,
  input wire data_misaligned_i,
  input wire [31:0] misaligned_addr_i,
  input wire irq_i,
  input wire [4:0] irq_id_i,
  input wire m_irq_enable_i,
  output wire irq_ack_o,
  output wire [4:0] irq_id_o,
  output wire [5:0] exc_cause_o,
  input wire lsu_load_err_i,
  input wire lsu_store_err_i,
  input wire [`DBG_SETS_W-1:0] dbg_settings_i,
  input wire dbg_req_i,
  output wire dbg_ack_o,
  input wire dbg_stall_i,
  output wire dbg_trap_o,
  input wire dbg_reg_rreq_i,
  input wire [4:0] dbg_reg_raddr_i,
  output wire [31:0] dbg_reg_rdata_o,
  input wire dbg_reg_wreq_i,
  input wire [4:0] dbg_reg_waddr_i,
  input wire [31:0] dbg_reg_wdata_i,
  input wire dbg_jump_req_i,
  input wire [31:0] regfile_wdata_lsu_i,
  input wire [31:0] regfile_wdata_ex_i,
  input wire [31:0] csr_rdata_i,
  output wire perf_jump_o,
  output reg perf_branch_o,
  output wire perf_tbranch_o
);
wire [31:0] instr;
wire deassert_we;
wire illegal_insn_dec;
wire illegal_reg_rv32e;
wire ebrk_insn;
wire mret_insn_dec;
wire ecall_insn_dec;
wire pipe_flush_dec;
wire branch_taken_ex;
wire branch_in_id;
reg branch_set_n;
reg branch_set_q;
reg branch_mux_dec;
reg jump_set;
reg jump_mux_dec;
wire jump_in_id;
reg instr_multicyle;
reg load_stall;
reg branch_stall;
reg jump_stall;
wire halt_id;
reg regfile_we;
reg select_data_rf;
wire [31:0] imm_i_type;
wire [31:0] imm_iz_type;
wire [31:0] imm_s_type;
wire [31:0] imm_sb_type;
wire [31:0] imm_u_type;
wire [31:0] imm_uj_type;
wire [31:0] imm_z_type;
wire [31:0] imm_s2_type;
wire [31:0] imm_bi_type;
wire [31:0] imm_s3_type;
wire [31:0] imm_vs_type;
wire [31:0] imm_vu_type;
reg [31:0] imm_a;
reg [31:0] imm_b;
wire irq_req_ctrl;
wire [4:0] irq_id_ctrl;
wire exc_ack;
wire exc_kill;
wire [4:0] regfile_addr_ra_id;
wire [4:0] regfile_addr_rb_id;
wire [4:0] regfile_alu_waddr_id;
wire regfile_we_id;
wire [31:0] regfile_data_ra_id;
wire [31:0] regfile_data_rb_id;
wire [`ALU_OP_WIDTH-1:0] alu_operator;
wire [2:0] alu_op_a_mux_sel;
wire [2:0] alu_op_b_mux_sel;
wire [0:0] imm_a_mux_sel;
wire [3:0] imm_b_mux_sel;
wire data_we_id;
wire [1:0] data_type_id;
wire data_sign_ext_id;
wire [1:0] data_reg_offset_id;
wire data_req_id;
wire data_load_event_id;
wire csr_access;
wire [1:0] csr_op;
wire csr_status;
wire [1:0] operand_a_fw_mux_sel;
reg [31:0] operand_a_fw_id;
wire [31:0] operand_b_fw_id;
reg [31:0] operand_b;
reg [31:0] alu_operand_a;
wire [31:0] alu_operand_b;
reg [31:0] regfile_wdata_mux;
reg regfile_we_mux;
reg [4:0] regfile_waddr_mux;
reg id_wb_fsm_cs;
reg id_wb_fsm_ns;
assign instr=instr_rdata_i;
assign imm_i_type={{20{instr[31]}},instr[31:20]};
assign imm_iz_type={20'b0,instr[31:20]};
assign imm_s_type={{20{instr[31]}},instr[31:25],instr[11:7]};
assign imm_sb_type={{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
assign imm_u_type={instr[31:12],12'b0};
assign imm_uj_type={{12{instr[31]}},instr[19:12],instr[20],instr[30:21],1'b0};
assign imm_z_type={27'b0,instr[`REG_S1]};
assign imm_s2_type={27'b0,instr[24:20]};
assign imm_bi_type={{27{instr[24]}},instr[24:20]};
assign imm_s3_type={27'b0,instr[29:25]};
assign imm_vs_type={{26{instr[24]}},instr[24:20],instr[25]};
assign imm_vu_type={26'b0,instr[24:20],instr[25]};
assign regfile_addr_ra_id=instr[`REG_S1];
assign regfile_addr_rb_id=instr[`REG_S2];
assign regfile_alu_waddr_id=instr[`REG_D];
assign illegal_reg_rv32e=1'b0;
assign clear_instr_valid_o=id_ready_o|halt_id;
assign branch_taken_ex=branch_in_id&branch_decision_i;
always @(*) 
begin
  case(alu_op_a_mux_sel)
    `OP_A_REGA_OR_FWD:alu_operand_a=operand_a_fw_id;
    `OP_A_CURRPC:alu_operand_a=pc_id_i;
    `OP_A_IMM:alu_operand_a=imm_a;
    default:alu_operand_a=operand_a_fw_id;
  endcase
end
always @(*) 
begin
  case(imm_a_mux_sel)
    `IMMA_Z:imm_a=imm_z_type;
    `IMMA_ZERO:imm_a=32'b0;
    default:imm_a=32'b0;
  endcase
end
always @(*) 
begin
  case(operand_a_fw_mux_sel)
    `SEL_MISALIGNED:operand_a_fw_id=misaligned_addr_i;
    `SEL_REGFILE:operand_a_fw_id=regfile_data_ra_id;
    default:operand_a_fw_id=regfile_data_ra_id;
  endcase
end
always @(*) 
begin
  case(imm_b_mux_sel)
    `IMMB_I:imm_b=imm_i_type;
    `IMMB_S:imm_b=imm_s_type;
    `IMMB_U:imm_b=imm_u_type;
    `IMMB_PCINCR:imm_b=(is_compressed_i&(~data_misaligned_i))?32'h2:32'h4;
    `IMMB_S2:imm_b=imm_s2_type;
    `IMMB_BI:imm_b=imm_bi_type;
    `IMMB_S3:imm_b=imm_s3_type;
    `IMMB_VS:imm_b=imm_vs_type;
    `IMMB_VU:imm_b=imm_vu_type;
    `IMMB_UJ:imm_b=imm_uj_type;
    `IMMB_SB:imm_b=imm_sb_type;
    default:imm_b=imm_i_type;
  endcase
end
always @(*) 
begin
  case(alu_op_b_mux_sel)
    `OP_B_REGB_OR_FWD:operand_b=regfile_data_rb_id;
    `OP_B_IMM:operand_b=imm_b;
    default:operand_b=regfile_data_rb_id;
  endcase
end
assign alu_operand_b=operand_b;
assign operand_b_fw_id=regfile_data_rb_id;
always @(*) 
begin
  if(dbg_reg_wreq_i) 
  begin
    regfile_wdata_mux=dbg_reg_wdata_i;
    regfile_waddr_mux=dbg_reg_waddr_i;
    regfile_we_mux=1'b1;
  end 
  else 
  begin
    regfile_we_mux=regfile_we;
    regfile_waddr_mux=regfile_alu_waddr_id;
    if(select_data_rf==`RF_LSU)
      regfile_wdata_mux=regfile_wdata_lsu_i;
    else 
    begin
      if(csr_access)
        regfile_wdata_mux=csr_rdata_i;
      else
        regfile_wdata_mux=regfile_wdata_ex_i;
    end
  end
end
rv32i_register_file
#(.RV32E(RV32E),.DATA_WIDTH(DATA_WIDTH))
registers_i
(
  .clk(clk),
  .rst_n(rst_n),
  .test_en_i(test_en_i),
  .raddr_a_i(regfile_addr_ra_id),
  .rdata_a_o(regfile_data_ra_id),
  .raddr_b_i((dbg_reg_rreq_i==1'b0)?regfile_addr_rb_id:dbg_reg_raddr_i),
  .rdata_b_o(regfile_data_rb_id),
  .waddr_a_i(regfile_waddr_mux),
  .wdata_a_i(regfile_wdata_mux),
  .we_a_i(regfile_we_mux)
);
assign dbg_reg_rdata_o=regfile_data_rb_id;
rv32i_decoder
decoder_i
(
  .deassert_we_i(deassert_we),
  .data_misaligned_i(data_misaligned_i),
  .branch_mux_i(branch_mux_dec),
  .jump_mux_i(jump_mux_dec),
  .illegal_insn_o(illegal_insn_dec),
  .ebrk_insn_o(ebrk_insn),
  .mret_insn_o(mret_insn_dec),
  .ecall_insn_o(ecall_insn_dec),
  .pipe_flush_o(pipe_flush_dec),
  .instr_rdata_i(instr),
  .illegal_c_insn_i(illegal_c_insn_i),
  .alu_operator_o(alu_operator),
  .alu_op_a_mux_sel_o(alu_op_a_mux_sel),
  .alu_op_b_mux_sel_o(alu_op_b_mux_sel),
  .imm_a_mux_sel_o(imm_a_mux_sel),
  .imm_b_mux_sel_o(imm_b_mux_sel),
  .regfile_we_o(regfile_we_id),
  .csr_access_o(csr_access),
  .csr_op_o(csr_op),
  .csr_status_o(csr_status),
  .data_req_o(data_req_id),
  .data_we_o(data_we_id),
  .data_type_o(data_type_id),
  .data_sign_extension_o(data_sign_ext_id),
  .data_reg_offset_o(data_reg_offset_id),
  .data_load_event_o(data_load_event_id),
  .jump_in_id_o(jump_in_id),
  .branch_in_id_o(branch_in_id)
);
rv32i_controller controller_i
(
  .clk(clk),
  .rst_n(rst_n),
  .fetch_enable_i(fetch_enable_i),
  .ctrl_busy_o(ctrl_busy_o),
  .first_fetch_o(core_ctrl_firstfetch_o),
  .is_decoding_o(is_decoding_o),
  .deassert_we_o(deassert_we),
  .illegal_insn_i(illegal_insn_dec|illegal_reg_rv32e),
  .ecall_insn_i(ecall_insn_dec),
  .mret_insn_i(mret_insn_dec),
  .pipe_flush_i(pipe_flush_dec),
  .ebrk_insn_i(ebrk_insn),
  .csr_status_i(csr_status),
  .instr_valid_i(instr_valid_i),
  .instr_req_o(instr_req_o),
  .pc_set_o(pc_set_o),
  .pc_mux_o(pc_mux_o),
  .exc_pc_mux_o(exc_pc_mux_o),
  .exc_cause_o(exc_cause_o),
  .data_misaligned_i(data_misaligned_i),
  .branch_in_id_i(branch_in_id),
  .branch_taken_ex_i(branch_taken_ex),
  .branch_set_i(branch_set_q),
  .jump_set_i(jump_set),
  .instr_multicyle_i(instr_multicyle),
  .irq_req_ctrl_i(irq_req_ctrl),
  .irq_id_ctrl_i(irq_id_ctrl),
  .m_IE_i(m_irq_enable_i),
  .irq_ack_o(irq_ack_o),
  .irq_id_o(irq_id_o),
  .exc_ack_o(exc_ack),
  .exc_kill_o(exc_kill),
  .csr_save_cause_o(csr_save_cause_o),
  .csr_cause_o(csr_cause_o),
  .csr_save_if_o(csr_save_if_o),
  .csr_save_id_o(csr_save_id_o),
  .csr_restore_mret_id_o(csr_restore_mret_id_o),
  .dbg_req_i(dbg_req_i),
  .dbg_ack_o(dbg_ack_o),
  .dbg_stall_i(dbg_stall_i),
  .dbg_jump_req_i(dbg_jump_req_i),
  .dbg_settings_i(dbg_settings_i),
  .dbg_trap_o(dbg_trap_o),
  .operand_a_fw_mux_sel_o(operand_a_fw_mux_sel),
  .halt_if_o(halt_if_o),
  .halt_id_o(halt_id),
  .id_ready_i(id_ready_o),
  .perf_jump_o(perf_jump_o),
  .perf_tbranch_o(perf_tbranch_o)
);
rv32i_int_controller int_controller_i
(
  .clk(clk),
  .rst_n(rst_n),
  .irq_req_ctrl_o(irq_req_ctrl),
  .irq_id_ctrl_o(irq_id_ctrl),
  .ctrl_ack_i(exc_ack),
  .ctrl_kill_i(exc_kill),
  .irq_i(irq_i),
  .irq_id_i(irq_id_i),
  .m_IE_i(m_irq_enable_i)
);
assign data_we_ex_o=data_we_id;
assign data_type_ex_o=data_type_id;
assign data_sign_ext_ex_o=data_sign_ext_id;
assign data_wdata_ex_o=regfile_data_rb_id;
assign data_req_ex_o=data_req_id;
assign data_reg_offset_ex_o=data_reg_offset_id;
assign data_load_event_ex_o=data_load_event_id;
assign alu_operator_ex_o=alu_operator;
assign alu_operand_a_ex_o=alu_operand_a;
assign alu_operand_b_ex_o=alu_operand_b;
assign csr_access_ex_o=csr_access;
assign csr_op_ex_o=csr_op;
assign branch_in_ex_o=branch_in_id;
always @(posedge clk or negedge rst_n) 
begin
  if(~rst_n) 
  begin
    id_wb_fsm_cs<=`S_IDLE;
    branch_set_q<=1'b0;
  end 
  else 
  begin
    id_wb_fsm_cs<=id_wb_fsm_ns;
    branch_set_q<=branch_set_n;
  end
end
always @(*) 
begin
  id_wb_fsm_ns=id_wb_fsm_cs;
  regfile_we=regfile_we_id;
  load_stall=1'b0;
  jump_stall=1'b0;
  branch_stall=1'b0;
  select_data_rf=`RF_EX;
  instr_multicyle=1'b0;
  branch_set_n=1'b0;
  branch_mux_dec=1'b0;
  jump_set=1'b0;
  jump_mux_dec=1'b0;
  perf_branch_o=1'b0;
  case(id_wb_fsm_cs)
    `S_IDLE:begin
      jump_mux_dec=1'b1;
      branch_mux_dec=1'b1;
      if(data_req_id) 
      begin
        regfile_we=1'b0;
        id_wb_fsm_ns=`S_WAIT_MULTICYCLE;
        load_stall=1'b1;
        instr_multicyle=1'b1;
      end 
      else if(branch_in_id) 
      begin
        id_wb_fsm_ns=branch_decision_i?`S_WAIT_MULTICYCLE:`S_IDLE;
        branch_stall=branch_decision_i;
        instr_multicyle=branch_decision_i;
        branch_set_n=branch_decision_i;
        perf_branch_o=1'b1;
      end 
     else if(jump_in_id) 
      begin
        regfile_we=1'b0;
        id_wb_fsm_ns=`S_WAIT_MULTICYCLE;
        jump_stall=1'b1;
        instr_multicyle=1'b1;
        jump_set=1'b1;
      end
    end
    `S_WAIT_MULTICYCLE:
    begin
      if(ex_ready_i) 
      begin
        regfile_we=regfile_we_id;
        id_wb_fsm_ns=`S_IDLE;
        load_stall=1'b0;
        select_data_rf=data_req_id?`RF_LSU:`RF_EX;
      end 
      else 
      begin
        regfile_we=1'b0;
        instr_multicyle=1'b1;
        if(data_req_id)
          load_stall=1'b1;
      end
    end
    default:id_wb_fsm_ns=`S_IDLE;
  endcase
end
assign id_ready_o=(~load_stall)&(~branch_stall)&(~jump_stall);
assign id_valid_o=(~halt_id)&id_ready_o;
endmodule
