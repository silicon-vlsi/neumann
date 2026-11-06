`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "If_Transaction.sv"
`include "If_Generator.sv"
`include "If_Driver.sv"
`include "If_Monitor.sv"
`include "If_Scoreboard.sv"
`include "If_Coverage.sv"
`include "If_Env.sv"

module If_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    If_interface intf (.clk(clk));

    rv32i_if_stage dut (
        .clk                 (clk),
        .rst_n               (intf.rst_n),
        .boot_addr_i         (intf.boot_addr_i),
        .req_i               (intf.req_i),
        .instr_req_o         (intf.instr_req_o),
        .instr_addr_o        (intf.instr_addr_o),
        .instr_gnt_i         (intf.instr_gnt_i),
        .instr_rvalid_i      (intf.instr_rvalid_i),
        .instr_rdata_i       (intf.instr_rdata_i),
        .instr_valid_id_o    (intf.instr_valid_id_o),
        .instr_rdata_id_o    (intf.instr_rdata_id_o),
        .is_compressed_id_o  (intf.is_compressed_id_o),
        .illegal_c_insn_id_o (intf.illegal_c_insn_id_o),
        .pc_if_o             (intf.pc_if_o),
        .pc_id_o             (intf.pc_id_o),
        .clear_instr_valid_i (intf.clear_instr_valid_i),
        .pc_set_i            (intf.pc_set_i),
        .exception_pc_reg_i  (intf.exception_pc_reg_i),
        .pc_mux_i            (intf.pc_mux_i),
        .exc_pc_mux_i        (intf.exc_pc_mux_i),
        .exc_vec_pc_mux_i    (intf.exc_vec_pc_mux_i),
        .jump_target_ex_i    (intf.jump_target_ex_i),
        .dbg_jump_addr_i     (intf.dbg_jump_addr_i),
        .halt_if_i           (intf.halt_if_i),
        .id_ready_i          (intf.id_ready_i),
        .if_valid_o          (intf.if_valid_o),
        .if_busy_o           (intf.if_busy_o),
        .perf_imiss_o        (intf.perf_imiss_o)
    );

    If_Env env;
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
