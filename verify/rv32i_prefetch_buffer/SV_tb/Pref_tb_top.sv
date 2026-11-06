`timescale 1ns/1ps
`include "Pref_Transaction.sv"
`include "Pref_Generator.sv"
`include "Pref_Driver.sv"
`include "Pref_Monitor.sv"
`include "Pref_Scoreboard.sv"
`include "Pref_Coverage.sv"
`include "Pref_Env.sv"

module Pref_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Pref_interface intf (.clk(clk));

    rv32i_prefetch_buffer dut (
        .clk            (clk),
        .rst_n          (intf.rst_n),
        .req_i          (intf.req_i),
        .branch_i       (intf.branch_i),
        .addr_i         (intf.addr_i),
        .ready_i        (intf.ready_i),
        .valid_o        (intf.valid_o),
        .rdata_o        (intf.rdata_o),
        .addr_o         (intf.addr_o),
        .instr_req_o    (intf.instr_req_o),
        .instr_gnt_i    (intf.instr_gnt_i),
        .instr_addr_o   (intf.instr_addr_o),
        .instr_rdata_i  (intf.instr_rdata_i),
        .instr_rvalid_i (intf.instr_rvalid_i),
        .busy_o         (intf.busy_o)
    );

    Pref_Env env;
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
