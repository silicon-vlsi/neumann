`timescale 1ns/1ps
`include "rv32i_defines.vh"

module alu_top;
    import alu_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    alu_if #(.OP_W(`ALU_OP_WIDTH)) vif (.clk(clk));

    rv32i_alu dut (
        .operator_i          (vif.operator_i),
        .operand_a_i         (vif.operand_a_i),
        .operand_b_i         (vif.operand_b_i),
        .adder_result_o      (vif.adder_result_o),
        .result_o            (vif.result_o),
        .comparison_result_o (vif.comparison_result_o),
        .is_equal_result_o   (vif.is_equal_result_o)
    );

    bind rv32i_alu alu_assertions #(.OP_W(`ALU_OP_WIDTH)) u_alu_sva (
        .clk   (alu_top.clk),
        .rst_n (1'b1),
        .*
    );

    initial begin
        $dumpfile("alu_top.vcd");
        $dumpvars(0, alu_top);

        begin
            test t;
            t = new(vif);
            t.run();
        end

        $finish;
    end

    initial begin
        #50000000;
        $display("ERROR: global timeout");
        $finish;
    end

endmodule
