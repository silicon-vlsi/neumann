`timescale 1ns/1ps
`include "Controller_Transaction.sv"
`include "Controller_Generator.sv"
`include "Controller_Driver.sv"
`include "Controller_Monitor.sv"
`include "Controller_Scorboard.sv"
`include "Controller_Coverage.sv"
`include "Controller_Env.sv"

module Controller_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Controller_interface intf (.clk(clk));

    rv32i_int_controller dut (
        .clk            (clk),
        .rst_n          (intf.rst_n),
        .irq_req_ctrl_o (intf.irq_req_ctrl_o),
        .irq_id_ctrl_o  (intf.irq_id_ctrl_o),
        .ctrl_ack_i     (intf.ctrl_ack_i),
        .ctrl_kill_i    (intf.ctrl_kill_i),
        .irq_i          (intf.irq_i),
        .irq_id_i       (intf.irq_id_i),
        .m_IE_i         (intf.m_IE_i)
    );

    Controller_Env env;
    int num_txn = 1000;

    initial begin
        if ($value$plusargs("NUMTXN=%d", num_txn))
            $display("[TOP] Number of transactions from command line: %0d", num_txn);
        env = new(intf, num_txn);
        env.run();
    end
endmodule
