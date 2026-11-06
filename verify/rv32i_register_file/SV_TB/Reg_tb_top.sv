`timescale 1ns/1ps
`include "Reg_Transaction.sv"
`include "Reg_Generator.sv"
`include "Reg_driver.sv"
`include "Reg_monitor.sv"
`include "Reg_Scoreboard.sv"
`include "Reg_Coverage.sv"
`include "Reg_Env.sv"

module Reg_tb_top;
    localparam RV32E      = 0;
    localparam DATA_WIDTH = 32;

    logic clk = 0;
    always #5 clk = ~clk;

    Reg_interface #(DATA_WIDTH) intf (.clk(clk));

    rv32i_register_file #(.RV32E(RV32E), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk       (clk),
        .rst_n     (intf.rst_n),
        .test_en_i (intf.test_en_i),
        .raddr_a_i (intf.raddr_a_i),
        .rdata_a_o (intf.rdata_a_o),
        .raddr_b_i (intf.raddr_b_i),
        .rdata_b_o (intf.rdata_b_o),
        .waddr_a_i (intf.waddr_a_i),
        .wdata_a_i (intf.wdata_a_i),
        .we_a_i    (intf.we_a_i)
    );

    Reg_Env #(RV32E, DATA_WIDTH) env;
    int num_txn = 1000;
    string test_type = "all";

    initial begin
        if ($value$plusargs("NUMTXN=%d", num_txn))
            $display("[TOP] Number of transactions from command line: %0d", num_txn);
        if ($value$plusargs("TEST=%s", test_type))
            $display("[TOP] Test from command line: %s", test_type);
        env = new(intf, num_txn, test_type);
        env.run();
    end

    initial begin
        #100000000;
        $display("ERROR: global timeout");
        $finish;
    end
endmodule
