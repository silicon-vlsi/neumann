`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "Dbg_Transaction.sv"
`include "Dbg_Generator.sv"
`include "Dbg_Driver.sv"
`include "Dbg_Monitor.sv"
`include "Dbg_Scoreboard.sv"
`include "Dbg_Coverage.sv"
`include "Dbg_Env.sv"

module Dbg_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Dbg_interface intf (.clk(clk));

    rv32i_debug_unit dut (
        .clk              (clk),
        .rst_n            (intf.rst_n),
        .debug_req_i      (intf.debug_req_i),
        .debug_gnt_o      (intf.debug_gnt_o),
        .debug_rvalid_o   (intf.debug_rvalid_o),
        .debug_addr_i     (intf.debug_addr_i),
        .debug_we_i       (intf.debug_we_i),
        .debug_wdata_i    (intf.debug_wdata_i),
        .debug_rdata_o    (intf.debug_rdata_o),
        .debug_halted_o   (intf.debug_halted_o),
        .debug_halt_i     (intf.debug_halt_i),
        .debug_resume_i   (intf.debug_resume_i),
        .settings_o       (intf.settings_o),
        .trap_i           (intf.trap_i),
        .exc_cause_i      (intf.exc_cause_i),
        .stall_o          (intf.stall_o),
        .dbg_req_o        (intf.dbg_req_o),
        .dbg_ack_i        (intf.dbg_ack_i),
        .regfile_rreq_o   (intf.regfile_rreq_o),
        .regfile_raddr_o  (intf.regfile_raddr_o),
        .regfile_rdata_i  (intf.regfile_rdata_i),
        .regfile_wreq_o   (intf.regfile_wreq_o),
        .regfile_waddr_o  (intf.regfile_waddr_o),
        .regfile_wdata_o  (intf.regfile_wdata_o),
        .csr_req_o        (intf.csr_req_o),
        .csr_addr_o       (intf.csr_addr_o),
        .csr_we_o         (intf.csr_we_o),
        .csr_wdata_o      (intf.csr_wdata_o),
        .csr_rdata_i      (intf.csr_rdata_i),
        .pc_if_i          (intf.pc_if_i),
        .pc_id_i          (intf.pc_id_i),
        .instr_valid_id_i (intf.instr_valid_id_i),
        .sleeping_i       (intf.sleeping_i),
        .jump_req_o       (intf.jump_req_o),
        .jump_addr_o      (intf.jump_addr_o)
    );

    Dbg_Env env;
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
