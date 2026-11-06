`timescale 1ns/1ps
`include "Transaction.sv"
`include "Generator.sv"
`include "Driver.sv"
`include "Monitor.sv"
`include "Scoreboard.sv"
`include "Coverage_file.sv"
`include "Environment.sv"
`include "rv32i_defines.vh"
module tb_top;

imm_interface imm();

rv32i_imm_gen dut
(
    .instr_i(imm.instr_i),
    .imm_sel_i(imm.imm_sel_i),
    .imm_o(imm.imm_o)
);

Environment env;
int num_txn=1000;
initial begin
 $display("Imm_gen VERIFICATION TESTBENCH");
if ($value$plusargs("NUMTXN=%d", num_txn))
        $display("[TOP] Number of transactions from command line: %0d", num_txn);
env=new(.vif(imm),.num_transactions(num_txn));
env.test();
$finish;
end
initial begin
    #10000000;
    $finish;
end
endmodule