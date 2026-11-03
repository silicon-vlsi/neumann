`include "rv32i_defines.vh"
module rv32i_core
#(
    parameter N_PERF_CNT=2,          // built-in perf counters: 2 = cycles+instructions, 11 = full set
    parameter N_EXT_PERF_COUNTER=0,
    parameter RV32E=0
)
(
    input clk_i,
    input rst_ni,
    input clock_en_i,
    input test_en_i,
    input [3:0]core_id_i,
    input [5:0] cluster_id_i,
    input [31:0] boot_addr_i,
    output instr_req_o,
    input instr_gnt_i,
    input instr_rvalid_i,
    output [31:0] instr_addr_o,
    input [31:0] instr_rdata_i,
    output data_req_o,
    input data_gnt_i,
    input data_rvalid_i,
    output data_we_o,
    output [3:0]data_be_o,
    output [31:0]data_wdata_o,
    output [31:0]data_addr_o,
    input [31:0]data_rdata_i,
    input data_err_i,
    input irq_i,
    input [4:0] irq_id_i,
    output irq_ack_o,
    output [4:0] irq_id_o,
    input debug_req_i,
    output debug_gnt_o,
    output debug_rvalid_o,
    input [14:0] debug_addr_i,
    input debug_we_i,
    input [31:0] debug_wdata_i,
    output [31:0] debug_rdata_o,
    output debug_halted_o,
    input debug_halt_i,
    input debug_resume_i,
    input fetch_enable_i,
    output core_busy_o,
    /* verilator lint_off ASCRANGE */   // [-1:0] when N_EXT_PERF_COUNTER = 0
    input [N_EXT_PERF_COUNTER-1:0]ext_perf_counters_i 
    /* verilator lint_on ASCRANGE */
);
wire instr_valid_id;
wire [31:0] instr_rdata_id;
wire is_compressed_id,illegal_c_insn_id;
wire [31:0] pc_if,pc_id;
wire clear_instr_valid,pc_set;
wire [2:0] pc_mux_id;
wire [1:0] exc_pc_mux_id;
wire [5:0] exc_cause;
wire lsu_load_err,lsu_store_err;
wire is_decoding,data_misaligned;
wire [31:0] misaligned_addr;
wire [31:0] jump_target_ex;
/* verilator lint_off UNUSEDSIGNAL */
wire branch_in_exc;   // id_stage status output, not used at core level
/* verilator lint_on UNUSEDSIGNAL */
wire branch_decision,ctrl_busy,if_busy,lsu_busy;
wire [`ALU_OP_WIDTH-1:0] alu_operator_ex;
wire [31:0] alu_operand_a_ex,alu_operand_b_ex;
wire [31:0] alu_adder_result_ex, regfile_wdata_ex;
wire csr_access_ex;
wire [1:0] csr_op_ex;
wire csr_access;
wire [1:0] csr_op;
wire [11:0] csr_addr,csr_addr_int;
wire [31:0] csr_rdata,csr_wdata;
wire data_we_ex,data_sign_ext_ex,data_req_ex;
wire [1:0] data_type_ex,data_reg_offset_ex;
wire [31:0] data_wdata_ex,regfile_wdata_lsu;
wire data_load_event_ex;
wire halt_if,id_ready,ex_ready,if_valid,id_valid,data_valid_lsu,instr_req_int,m_irq_enable;
wire [31:0] mepc;
wire csr_save_cause,csr_save_if,csr_save_id;
wire [5:0] csr_cause;
wire csr_restore_mret_id;
wire [`DBG_SETS_W-1:0] dbg_settings;
wire dbg_req,dbg_ack,dbg_stall,dbg_trap,dbg_reg_rreq;
wire [4:0] dbg_reg_raddr;
wire [31:0] dbg_reg_rdata;
wire dbg_csr_req;
wire [11:0] dbg_csr_addr;
wire dbg_csr_we,dbg_jump_req;
wire [31:0] dbg_csr_wdata,dbg_jump_addr;
wire perf_imiss,perf_jump,perf_branch,perf_tbranch;
wire core_ctrl_firstfetch,core_busy_int;
reg core_busy_q;
wire clk,clock_en,dbg_busy,sleeping;
wire dbg_reg_wreq;
wire [4:0] dbg_reg_waddr;
wire [31:0] dbg_reg_wdata;

assign core_busy_int =(data_load_event_ex & data_req_o) ? if_busy : (if_busy | ctrl_busy | lsu_busy );

always @(posedge clk or negedge rst_ni)
begin
    if(rst_ni==1'b0)
    begin
        core_busy_q<=1'b0;
    end 
    else
    begin 
        core_busy_q<=core_busy_int;
    end
end

assign core_busy_o = core_ctrl_firstfetch ? 1'b1 :core_busy_q;
assign dbg_busy = dbg_req|dbg_csr_req|dbg_jump_req|dbg_reg_wreq|debug_req_i;
assign clock_en = clock_en_i|core_busy_o|dbg_busy;
assign sleeping = (~fetch_enable_i) & (~core_busy_o) ;

cluster_clock_gating clk1
(
    .clk_i(clk_i),
    .en_i(clock_en),
    .test_en_i(test_en_i),
    .clk_o(clk)
);

rv32i_if_stage rv32i_if_stage
(
    .clk(clk),
    .rst_n(rst_ni),
    .boot_addr_i(boot_addr_i),
    .req_i(instr_req_int),
    .instr_req_o(instr_req_o),
    .instr_addr_o(instr_addr_o),
    .instr_gnt_i(instr_gnt_i),
    .instr_rvalid_i(instr_rvalid_i),
    .instr_rdata_i(instr_rdata_i),
    .instr_valid_id_o(instr_valid_id),
    .instr_rdata_id_o(instr_rdata_id),
    .is_compressed_id_o(is_compressed_id),
    .illegal_c_insn_id_o(illegal_c_insn_id),
    .pc_if_o(pc_if),
    .pc_id_o(pc_id),
    .clear_instr_valid_i(clear_instr_valid),
    .pc_set_i(pc_set),
    .exception_pc_reg_i(mepc),
    .pc_mux_i(pc_mux_id),
    .exc_pc_mux_i(exc_pc_mux_id),
    .exc_vec_pc_mux_i(exc_cause[4:0]),
    .dbg_jump_addr_i(dbg_jump_addr),
    .jump_target_ex_i(jump_target_ex),
    .halt_if_i(halt_if),
    .id_ready_i(id_ready),
    .if_valid_o(if_valid),
    .if_busy_o(if_busy),
    .perf_imiss_o(perf_imiss)
);

rv32i_id_stage
#(
    .RV32E(RV32E)
)
id_stage_i
(
    .clk(clk),
    .rst_n(rst_ni),
    .test_en_i(test_en_i),
    .fetch_enable_i(fetch_enable_i),
    .ctrl_busy_o(ctrl_busy),
    .core_ctrl_firstfetch_o(core_ctrl_firstfetch),
    .is_decoding_o(is_decoding),
    .instr_valid_i(instr_valid_id),
    .instr_rdata_i(instr_rdata_id),
    .instr_req_o(instr_req_int),
    .branch_in_ex_o(branch_in_exc),
    .branch_decision_i(branch_decision),
    .clear_instr_valid_o(clear_instr_valid),
    .pc_set_o(pc_set),
    .pc_mux_o(pc_mux_id),
    .exc_pc_mux_o(exc_pc_mux_id),
    .illegal_c_insn_i(illegal_c_insn_id),
    .is_compressed_i(is_compressed_id),
    .pc_id_i(pc_id),
    .halt_if_o(halt_if),
    .id_ready_o(id_ready),
    .ex_ready_i(ex_ready),
    .id_valid_o(id_valid),
    .alu_operator_ex_o(alu_operator_ex),
    .alu_operand_a_ex_o(alu_operand_a_ex),
    .alu_operand_b_ex_o(alu_operand_b_ex),
    .csr_access_ex_o(csr_access_ex),
    .csr_op_ex_o(csr_op_ex),
    .csr_cause_o(csr_cause),
    .csr_save_if_o(csr_save_if),
    .csr_save_id_o(csr_save_id),
    .csr_restore_mret_id_o(csr_restore_mret_id),
    .csr_save_cause_o(csr_save_cause),
    .data_req_ex_o(data_req_ex),
    .data_we_ex_o(data_we_ex),
    .data_type_ex_o(data_type_ex),
    .data_sign_ext_ex_o(data_sign_ext_ex),
    .data_reg_offset_ex_o(data_reg_offset_ex),
    .data_load_event_ex_o(data_load_event_ex),
    .data_wdata_ex_o(data_wdata_ex),
    .data_misaligned_i(data_misaligned),
    .misaligned_addr_i(misaligned_addr),
    .irq_i(irq_i),
    .irq_id_i(irq_id_i),
    .m_irq_enable_i(m_irq_enable),
    .irq_ack_o(irq_ack_o),
    .irq_id_o(irq_id_o),
    .exc_cause_o(exc_cause),
    .lsu_load_err_i(lsu_load_err),
    .lsu_store_err_i(lsu_store_err),
    .dbg_settings_i(dbg_settings),
    .dbg_req_i(dbg_req),
    .dbg_ack_o(dbg_ack),
    .dbg_stall_i(dbg_stall),
    .dbg_trap_o(dbg_trap),
    .dbg_reg_rreq_i(dbg_reg_rreq),
    .dbg_reg_raddr_i(dbg_reg_raddr),
    .dbg_reg_rdata_o(dbg_reg_rdata),
    .dbg_reg_wreq_i(dbg_reg_wreq),
    .dbg_reg_waddr_i(dbg_reg_waddr),
    .dbg_reg_wdata_i(dbg_reg_wdata),
    .dbg_jump_req_i(dbg_jump_req),
    .regfile_wdata_lsu_i(regfile_wdata_lsu),
    .regfile_wdata_ex_i(regfile_wdata_ex),
    .csr_rdata_i(csr_rdata),
    .perf_jump_o(perf_jump),
    .perf_branch_o(perf_branch),
    .perf_tbranch_o(perf_tbranch)
);

rv32i_ex_block ex_block
(
    .clk(clk),
    .rst_n(rst_ni),
    .alu_operator_i(alu_operator_ex),        
    .alu_operand_a_i(alu_operand_a_ex),
    .alu_operand_b_i(alu_operand_b_ex),
    .alu_adder_result_ex_o(alu_adder_result_ex),
    .regfile_wdata_ex_o(regfile_wdata_ex),
    .jump_target_o(jump_target_ex),
    .branch_decision_o(branch_decision),
    .lsu_en_i(data_req_ex),
    .lsu_ready_ex_i(data_valid_lsu),      
    .ex_ready_o(ex_ready) 
);

rv32i_load_store_unit load_store
(
    .clk(clk),
    .rst_n(rst_ni),
    .data_req_o(data_req_o),
    .data_gnt_i(data_gnt_i),
    .data_rvalid_i(data_rvalid_i),
    .data_err_i(data_err_i),
    .data_addr_o(data_addr_o),
    .data_we_o(data_we_o),
    .data_be_o(data_be_o),
    .data_wdata_o(data_wdata_o),
    .data_rdata_i(data_rdata_i),
    .data_we_ex_i(data_we_ex),
    .data_type_ex_i(data_type_ex),
    .data_wdata_ex_i(data_wdata_ex),
    .data_reg_offset_ex_i(data_reg_offset_ex),
    .data_sign_ext_ex_i(data_sign_ext_ex),
    .data_rdata_ex_o(regfile_wdata_lsu),
    .data_req_ex_i(data_req_ex),
    .adder_result_ex_i(alu_adder_result_ex),
    .data_misaligned_o(data_misaligned),
    .misaligned_addr_o(misaligned_addr),
    .load_err_o(lsu_load_err),
    .store_err_o(lsu_store_err),
    /* verilator lint_off PINCONNECTEMPTY */
    .lsu_update_addr_o(),
    /* verilator lint_on PINCONNECTEMPTY */
    .data_valid_o(data_valid_lsu),
    .busy_o(lsu_busy)
);

rv32i_cs_registers
#(
    .N_PERF_CNT(N_PERF_CNT),
    .N_EXT_CNT(N_EXT_PERF_COUNTER)
)
cs_registers_i
(
    .clk(clk),
    .rst_n(rst_ni),
    .core_id_i(core_id_i),
    .cluster_id_i(cluster_id_i),
    .boot_addr_i(boot_addr_i[31:8]),
    .csr_access_i(csr_access),
    .csr_addr_i(csr_addr),
    .csr_wdata_i(csr_wdata),
    .csr_op_i(csr_op),
    .csr_rdata_o(csr_rdata),
    .m_irq_enable_o(m_irq_enable),
    .mepc_o(mepc),
    .pc_if_i(pc_if),
    .pc_id_i(pc_id),
    .csr_save_if_i(csr_save_if),
    .csr_save_id_i(csr_save_id),
    .csr_restore_mret_i(csr_restore_mret_id),
    .csr_cause_i(csr_cause),
    .csr_save_cause_i(csr_save_cause),
    .if_valid_i(if_valid),
    .id_valid_i(id_valid),
    .is_compressed_i(is_compressed_id),
    .is_decoding_i(is_decoding),
    .imiss_i(perf_imiss),
    .pc_set_i(pc_set),
    .jump_i(perf_jump),
    .branch_i(perf_branch),
    .branch_taken_i(perf_tbranch),
    .mem_load_i(data_req_o&data_gnt_i&(~data_we_o)),
    .mem_store_i(data_req_o&data_gnt_i&data_we_o),
    .ext_counters_i(ext_perf_counters_i)
);

assign csr_access = (dbg_csr_req == 1'b0) ? csr_access_ex : 1'b1;
assign csr_addr = (dbg_csr_req == 1'b0) ? csr_addr_int : dbg_csr_addr;
assign csr_wdata = (dbg_csr_req == 1'b0) ? alu_operand_a_ex : dbg_csr_wdata;
assign csr_op = (dbg_csr_req == 1'b0) ? csr_op_ex : (dbg_csr_we == 1'b1 ? `CSR_OP_WRITE: `CSR_OP_NONE);
assign csr_addr_int = csr_access_ex ? alu_operand_b_ex[11:0] : 0;

rv32i_debug_unit debug_unit
(
    .clk(clk_i), 
    .rst_n(rst_ni),
    .debug_req_i(debug_req_i),
    .debug_gnt_o(debug_gnt_o),
    .debug_rvalid_o(debug_rvalid_o),
    .debug_addr_i(debug_addr_i),
    .debug_we_i(debug_we_i),
    .debug_wdata_i(debug_wdata_i),
    .debug_rdata_o(debug_rdata_o),
    .debug_halt_i(debug_halt_i),
    .debug_resume_i(debug_resume_i),
    .debug_halted_o(debug_halted_o),
    .settings_o(dbg_settings),
    .trap_i(dbg_trap),
    .exc_cause_i(exc_cause),
    .stall_o(dbg_stall),
    .dbg_req_o(dbg_req),
    .dbg_ack_i(dbg_ack),
    .regfile_rreq_o(dbg_reg_rreq),
    .regfile_raddr_o(dbg_reg_raddr),
    .regfile_rdata_i(dbg_reg_rdata),
    .regfile_wreq_o(dbg_reg_wreq),
    .regfile_waddr_o(dbg_reg_waddr),
    .regfile_wdata_o(dbg_reg_wdata),
    .csr_req_o(dbg_csr_req),
    .csr_addr_o(dbg_csr_addr),
    .csr_we_o(dbg_csr_we),
    .csr_wdata_o(dbg_csr_wdata),
    .csr_rdata_i(csr_rdata),
    .pc_if_i(pc_if),
    .pc_id_i(pc_id),
    .instr_valid_id_i(instr_valid_id),
    .sleeping_i(sleeping),
    .jump_addr_o(dbg_jump_addr),
    .jump_req_o(dbg_jump_req)  
);

endmodule
