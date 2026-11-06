`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "Cdec_Transaction.sv"
`include "Cdec_Generator.sv"
`include "Cdec_Driver.sv"
`include "Cdec_Monitor.sv"
`include "Cdec_Scoreboard.sv"
`include "Cdec_Coverage.sv"
`include "Cdec_Env.sv"

module Cdec_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Cdec_interface intf (.clk(clk));

    rv32i_compressed_decoder dut (
        .instr_i         (intf.instr_i),
        .instr_o         (intf.instr_o),
        .is_compressed_o (intf.is_compressed_o),
        .illegal_instr_o (intf.illegal_instr_o)
    );

    Cdec_Env env;
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
