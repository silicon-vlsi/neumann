`timescale 1ns/1ps
`include "Fifo_Transaction.sv"
`include "Fifo_Generator.sv"
`include "Fifo_Driver.sv"
`include "Fifo_Monitor.sv"
`include "Fifo_Scoreboard.sv"
`include "Fifo_Coverage.sv"
`include "Fifo_Env.sv"

module Fifo_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Fifo_interface intf (.clk(clk));

    rv32i_fetch_fifo dut (
        .clk                (clk),
        .rst_n              (intf.rst_n),
        .clear_i            (intf.clear_i),
        .in_addr_i          (intf.in_addr_i),
        .in_rdata_i         (intf.in_rdata_i),
        .in_valid_i         (intf.in_valid_i),
        .in_ready_o         (intf.in_ready_o),
        .out_valid_o        (intf.out_valid_o),
        .out_ready_i        (intf.out_ready_i),
        .out_rdata_o        (intf.out_rdata_o),
        .out_addr_o         (intf.out_addr_o),
        .out_valid_stored_o (intf.out_valid_stored_o)
    );

    Fifo_Env env;
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
