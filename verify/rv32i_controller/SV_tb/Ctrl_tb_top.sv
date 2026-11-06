`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "Ctrl_Transaction.sv"
`include "Ctrl_Generator.sv"
`include "Ctrl_Driver.sv"
`include "Ctrl_Monitor.sv"
`include "Ctrl_Scoreboard.sv"
`include "Ctrl_Coverage.sv"
`include "Ctrl_Env.sv"

module Ctrl_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Ctrl_interface intf (.clk(clk));

    rv32i_controller dut (
        .clk                    (clk),
        .rst_n                  (intf.rst_n),
        .fetch_enable_i         (intf.fetch_enable_i),
        .ctrl_busy_o            (intf.ctrl_busy_o),
        .first_fetch_o          (intf.first_fetch_o),
        .is_decoding_o          (intf.is_decoding_o),
        .deassert_we_o          (intf.deassert_we_o),
        .illegal_insn_i         (intf.illegal_insn_i),
        .ecall_insn_i           (intf.ecall_insn_i),
        .mret_insn_i            (intf.mret_insn_i),
        .pipe_flush_i           (intf.pipe_flush_i),
        .ebrk_insn_i            (intf.ebrk_insn_i),
        .csr_status_i           (intf.csr_status_i),
        .instr_valid_i          (intf.instr_valid_i),
        .instr_req_o            (intf.instr_req_o),
        .pc_set_o               (intf.pc_set_o),
        .pc_mux_o               (intf.pc_mux_o),
        .exc_pc_mux_o           (intf.exc_pc_mux_o),
        .data_misaligned_i      (intf.data_misaligned_i),
        .branch_in_id_i         (intf.branch_in_id_i),
        .branch_taken_ex_i      (intf.branch_taken_ex_i),
        .branch_set_i           (intf.branch_set_i),
        .jump_set_i             (intf.jump_set_i),
        .instr_multicyle_i      (intf.instr_multicyle_i),
        .irq_req_ctrl_i         (intf.irq_req_ctrl_i),
        .irq_id_ctrl_i          (intf.irq_id_ctrl_i),
        .m_IE_i                 (intf.m_IE_i),
        .irq_ack_o              (intf.irq_ack_o),
        .irq_id_o               (intf.irq_id_o),
        .exc_cause_o            (intf.exc_cause_o),
        .exc_ack_o              (intf.exc_ack_o),
        .exc_kill_o             (intf.exc_kill_o),
        .csr_save_if_o          (intf.csr_save_if_o),
        .csr_save_id_o          (intf.csr_save_id_o),
        .csr_cause_o            (intf.csr_cause_o),
        .csr_restore_mret_id_o  (intf.csr_restore_mret_id_o),
        .csr_save_cause_o       (intf.csr_save_cause_o),
        .dbg_req_i              (intf.dbg_req_i),
        .dbg_ack_o              (intf.dbg_ack_o),
        .dbg_stall_i            (intf.dbg_stall_i),
        .dbg_jump_req_i         (intf.dbg_jump_req_i),
        .dbg_settings_i         (intf.dbg_settings_i),
        .dbg_trap_o             (intf.dbg_trap_o),
        .operand_a_fw_mux_sel_o (intf.operand_a_fw_mux_sel_o),
        .halt_if_o              (intf.halt_if_o),
        .halt_id_o              (intf.halt_id_o),
        .id_ready_i             (intf.id_ready_i),
        .perf_jump_o            (intf.perf_jump_o),
        .perf_tbranch_o         (intf.perf_tbranch_o)
    );

    assign intf.dbg_cs = dut.ctrl_fsm_cs;

    Ctrl_Env env;
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
