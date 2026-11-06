`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "Id_Transaction.sv"
`include "Id_Generator.sv"
`include "Id_Driver.sv"
`include "Id_Monitor.sv"
`include "Id_Scoreboard.sv"
`include "Id_Coverage.sv"
`include "Id_Env.sv"

module Id_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Id_interface intf (.clk(clk));

    rv32i_id_stage #(.DATA_WIDTH(32), .RV32E(0)) dut (
        .clk                    (clk),
        .rst_n                  (intf.rst_n),
        .test_en_i              (intf.test_en_i),
        .fetch_enable_i         (intf.fetch_enable_i),
        .ctrl_busy_o            (intf.ctrl_busy_o),
        .core_ctrl_firstfetch_o (intf.core_ctrl_firstfetch_o),
        .is_decoding_o          (intf.is_decoding_o),
        .instr_valid_i          (intf.instr_valid_i),
        .instr_rdata_i          (intf.instr_rdata_i),
        .instr_req_o            (intf.instr_req_o),
        .branch_in_ex_o         (intf.branch_in_ex_o),
        .branch_decision_i      (intf.branch_decision_i),
        .clear_instr_valid_o    (intf.clear_instr_valid_o),
        .pc_set_o               (intf.pc_set_o),
        .pc_mux_o               (intf.pc_mux_o),
        .exc_pc_mux_o           (intf.exc_pc_mux_o),
        .illegal_c_insn_i       (intf.illegal_c_insn_i),
        .is_compressed_i        (intf.is_compressed_i),
        .pc_id_i                (intf.pc_id_i),
        .halt_if_o              (intf.halt_if_o),
        .id_ready_o             (intf.id_ready_o),
        .ex_ready_i             (intf.ex_ready_i),
        .id_valid_o             (intf.id_valid_o),
        .alu_operator_ex_o      (intf.alu_operator_ex_o),
        .alu_operand_a_ex_o     (intf.alu_operand_a_ex_o),
        .alu_operand_b_ex_o     (intf.alu_operand_b_ex_o),
        .csr_access_ex_o        (intf.csr_access_ex_o),
        .csr_op_ex_o            (intf.csr_op_ex_o),
        .csr_cause_o            (intf.csr_cause_o),
        .csr_save_if_o          (intf.csr_save_if_o),
        .csr_save_id_o          (intf.csr_save_id_o),
        .csr_restore_mret_id_o  (intf.csr_restore_mret_id_o),
        .csr_save_cause_o       (intf.csr_save_cause_o),
        .data_req_ex_o          (intf.data_req_ex_o),
        .data_we_ex_o           (intf.data_we_ex_o),
        .data_type_ex_o         (intf.data_type_ex_o),
        .data_sign_ext_ex_o     (intf.data_sign_ext_ex_o),
        .data_reg_offset_ex_o   (intf.data_reg_offset_ex_o),
        .data_load_event_ex_o   (intf.data_load_event_ex_o),
        .data_wdata_ex_o        (intf.data_wdata_ex_o),
        .data_misaligned_i      (intf.data_misaligned_i),
        .misaligned_addr_i      (intf.misaligned_addr_i),
        .irq_i                  (intf.irq_i),
        .irq_id_i               (intf.irq_id_i),
        .m_irq_enable_i         (intf.m_irq_enable_i),
        .irq_ack_o              (intf.irq_ack_o),
        .irq_id_o               (intf.irq_id_o),
        .exc_cause_o            (intf.exc_cause_o),
        .lsu_load_err_i         (intf.lsu_load_err_i),
        .lsu_store_err_i        (intf.lsu_store_err_i),
        .dbg_settings_i         (intf.dbg_settings_i),
        .dbg_req_i              (intf.dbg_req_i),
        .dbg_ack_o              (intf.dbg_ack_o),
        .dbg_stall_i            (intf.dbg_stall_i),
        .dbg_trap_o             (intf.dbg_trap_o),
        .dbg_reg_rreq_i         (intf.dbg_reg_rreq_i),
        .dbg_reg_raddr_i        (intf.dbg_reg_raddr_i),
        .dbg_reg_rdata_o        (intf.dbg_reg_rdata_o),
        .dbg_reg_wreq_i         (intf.dbg_reg_wreq_i),
        .dbg_reg_waddr_i        (intf.dbg_reg_waddr_i),
        .dbg_reg_wdata_i        (intf.dbg_reg_wdata_i),
        .dbg_jump_req_i         (intf.dbg_jump_req_i),
        .regfile_wdata_lsu_i    (intf.regfile_wdata_lsu_i),
        .regfile_wdata_ex_i     (intf.regfile_wdata_ex_i),
        .csr_rdata_i            (intf.csr_rdata_i),
        .perf_jump_o            (intf.perf_jump_o),
        .perf_branch_o          (intf.perf_branch_o),
        .perf_tbranch_o         (intf.perf_tbranch_o)
    );

    assign intf.dbg_wb_cs   = dut.id_wb_fsm_cs;
    assign intf.dbg_halt_id = dut.halt_id;

    Id_Env env;
    int num_txn = 1000;

    initial begin
        if ($value$plusargs("NUMTXN=%d", num_txn))
            $display("[TOP] Number of transactions from command line: %0d", num_txn);
        env = new(intf, num_txn);
        env.run();
    end

    initial begin
        #100000000;
        $display("ERROR: global timeout");
        $finish;
    end
endmodule
