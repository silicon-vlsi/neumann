`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "Decoder_Transaction.sv"
`include "Decoder_Generator.sv"
`include "Decoder_Driver.sv"
`include "Decoder_Monitor.sv"
`include "Decoder_Scoreboard.sv"
`include "Decoder_Coverage.sv"
`include "Decoder_Env.sv"

module Decoder_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Decoder_interface intf (.clk(clk));

    rv32i_decoder dut (
        .deassert_we_i         (intf.deassert_we_i),
        .data_misaligned_i     (intf.data_misaligned_i),
        .branch_mux_i          (intf.branch_mux_i),
        .jump_mux_i            (intf.jump_mux_i),
        .illegal_insn_o        (intf.illegal_insn_o),
        .ebrk_insn_o           (intf.ebrk_insn_o),
        .mret_insn_o           (intf.mret_insn_o),
        .ecall_insn_o          (intf.ecall_insn_o),
        .pipe_flush_o          (intf.pipe_flush_o),
        .instr_rdata_i         (intf.instr_rdata_i),
        .illegal_c_insn_i      (intf.illegal_c_insn_i),
        .alu_operator_o        (intf.alu_operator_o),
        .alu_op_a_mux_sel_o    (intf.alu_op_a_mux_sel_o),
        .alu_op_b_mux_sel_o    (intf.alu_op_b_mux_sel_o),
        .imm_a_mux_sel_o       (intf.imm_a_mux_sel_o),
        .imm_b_mux_sel_o       (intf.imm_b_mux_sel_o),
        .regfile_we_o          (intf.regfile_we_o),
        .csr_access_o          (intf.csr_access_o),
        .csr_op_o              (intf.csr_op_o),
        .csr_status_o          (intf.csr_status_o),
        .data_req_o            (intf.data_req_o),
        .data_we_o             (intf.data_we_o),
        .data_type_o           (intf.data_type_o),
        .data_sign_extension_o (intf.data_sign_extension_o),
        .data_reg_offset_o     (intf.data_reg_offset_o),
        .data_load_event_o     (intf.data_load_event_o),
        .jump_in_id_o          (intf.jump_in_id_o),
        .branch_in_id_o        (intf.branch_in_id_o)
    );

    Decoder_Env env;
    int num_txn = 1000;

    initial begin
        if ($value$plusargs("NUMTXN=%d", num_txn))
            $display("[TOP] Number of transactions from command line: %0d", num_txn);
        env = new(intf, num_txn);
        env.run();
    end
endmodule
