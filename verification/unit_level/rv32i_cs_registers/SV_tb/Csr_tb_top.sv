`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "Csr_tb_cfg.svh"
`include "Csr_Transaction.sv"
`include "Csr_Generator.sv"
`include "Csr_Driver.sv"
`include "Csr_Monitor.sv"
`include "Csr_Scoreboard.sv"
`include "Csr_Coverage.sv"
`include "Csr_Env.sv"

module Csr_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Csr_interface intf (.clk(clk));

    rv32i_cs_registers #(.N_PERF_CNT(`CSR_N_PERF_CNT), .N_EXT_CNT(0)) dut (
        .clk                (clk),
        .rst_n              (intf.rst_n),
        .core_id_i          (intf.core_id_i),
        .cluster_id_i       (intf.cluster_id_i),
        .boot_addr_i        (intf.boot_addr_i),
        .csr_access_i       (intf.csr_access_i),
        .csr_addr_i         (intf.csr_addr_i),
        .csr_wdata_i        (intf.csr_wdata_i),
        .csr_op_i           (intf.csr_op_i),
        .csr_rdata_o        (intf.csr_rdata_o),
        .m_irq_enable_o     (intf.m_irq_enable_o),
        .mepc_o             (intf.mepc_o),
        .pc_if_i            (intf.pc_if_i),
        .pc_id_i            (intf.pc_id_i),
        .csr_save_if_i      (intf.csr_save_if_i),
        .csr_save_id_i      (intf.csr_save_id_i),
        .csr_restore_mret_i (intf.csr_restore_mret_i),
        .csr_cause_i        (intf.csr_cause_i),
        .csr_save_cause_i   (intf.csr_save_cause_i),
        .if_valid_i         (intf.if_valid_i),
        .id_valid_i         (intf.id_valid_i),
        .is_compressed_i    (intf.is_compressed_i),
        .is_decoding_i      (intf.is_decoding_i),
        .imiss_i            (intf.imiss_i),
        .pc_set_i           (intf.pc_set_i),
        .jump_i             (intf.jump_i),
        .branch_i           (intf.branch_i),
        .branch_taken_i     (intf.branch_taken_i),
        .mem_load_i         (intf.mem_load_i),
        .mem_store_i        (intf.mem_store_i),
        .ext_counters_i     ('0)
    );

    Csr_Env env;
    int num_txn = 1000;

    initial begin
        if ($value$plusargs("NUMTXN=%d", num_txn))
            $display("[TOP] Number of transactions from command line: %0d", num_txn);
        $display("[TOP] DUT N_PERF_CNT = %0d", `CSR_N_PERF_CNT);
        env = new(intf, num_txn);
        env.run();
    end

    initial begin
        #100000000;
        $display("ERROR: global timeout");
        $finish;
    end
endmodule
