`timescale 1ns/1ps
`include "rv32i_defines.vh"
`include "Ex_Transaction.sv"
`include "Ex_Generator.sv"
`include "Ex_Driver.sv"
`include "Ex_Monitor.sv"
`include "Ex_Scoreboard.sv"
`include "Ex_Coverage.sv"
`include "Ex_Env.sv"

module Ex_tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    Ex_interface intf (.clk(clk));

    rv32i_ex_block dut (
        .clk                   (clk),
        .rst_n                 (intf.rst_n),
        .alu_operator_i        (intf.alu_operator_i),
        .alu_operand_a_i       (intf.alu_operand_a_i),
        .alu_operand_b_i       (intf.alu_operand_b_i),
        .alu_adder_result_ex_o (intf.alu_adder_result_ex_o),
        .regfile_wdata_ex_o    (intf.regfile_wdata_ex_o),
        .jump_target_o         (intf.jump_target_o),
        .branch_decision_o     (intf.branch_decision_o),
        .lsu_en_i              (intf.lsu_en_i),
        .lsu_ready_ex_i        (intf.lsu_ready_ex_i),
        .ex_ready_o            (intf.ex_ready_o)
    );

    Ex_Env env;
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
