`include "rv32i_defines.vh"
module Cdec_Assertions (
    input logic        clk,
    input logic [31:0] instr_i,
    input logic [31:0] instr_o,
    input logic        is_compressed_o,
    input logic        illegal_instr_o
);

    property p_comp_flag;
        @(posedge clk) disable iff ($isunknown(instr_i)) is_compressed_o == (instr_i[1:0] != 2'b11);
    endproperty
    a_comp_flag : assert property (p_comp_flag)
        else $error("CDEC: is_compressed_o wrong for %h", instr_i);

    property p_passthrough;
        @(posedge clk) disable iff ($isunknown(instr_i)) (instr_i[1:0] == 2'b11) |-> (instr_o == instr_i) && !illegal_instr_o;
    endproperty
    a_passthrough : assert property (p_passthrough)
        else $error("CDEC: 32-bit instruction not passed through");

    property p_out_32bit;
        @(posedge clk) disable iff ($isunknown(instr_i)) (is_compressed_o && !illegal_instr_o) |-> (instr_o[1:0] == 2'b11);
    endproperty
    a_out_32bit : assert property (p_out_32bit)
        else $error("CDEC: expanded instruction is not a 32-bit encoding");

    property p_out_opcode;
        @(posedge clk) disable iff ($isunknown(instr_i)) (is_compressed_o && !illegal_instr_o) |->
            (instr_o[6:0] inside {`OPCODE_OPIMM, `OPCODE_OP, `OPCODE_LOAD, `OPCODE_STORE, `OPCODE_LUI,
                                  `OPCODE_JAL, `OPCODE_JALR, `OPCODE_BRANCH, `OPCODE_SYSTEM});
    endproperty
    a_out_opcode : assert property (p_out_opcode)
        else $error("CDEC: unexpected opcode %h after expansion", instr_o[6:0]);

    property p_reserved_q0;
        @(posedge clk) disable iff ($isunknown(instr_i)) (instr_i[1:0] == 2'b00) && (instr_i[15:13] inside {3'b001, 3'b011, 3'b100, 3'b101, 3'b111})
            |-> illegal_instr_o;
    endproperty
    a_reserved_q0 : assert property (p_reserved_q0)
        else $error("CDEC: unsupported quadrant-0 encoding %h not flagged illegal", instr_i[15:0]);

    property p_no_x_out;
        @(posedge clk) disable iff ($isunknown(instr_i)) !$isunknown(instr_i) |-> !$isunknown({instr_o, is_compressed_o, illegal_instr_o});
    endproperty
    a_no_x_out : assert property (p_no_x_out)
        else $error("CDEC: X/Z on outputs");

    c_ebreak : cover property (@(posedge clk) disable iff ($isunknown(instr_i)) instr_i[15:0] == 16'h9002);
    c_jr     : cover property (@(posedge clk) disable iff ($isunknown(instr_i)) (instr_i[15:12] == 4'b1000) && (instr_i[6:0] == 7'b0000010));
    c_ill_q1 : cover property (@(posedge clk) disable iff ($isunknown(instr_i)) (instr_i[1:0] == 2'b01) && illegal_instr_o);

endmodule

bind rv32i_compressed_decoder Cdec_Assertions u_assert (
    .clk             (Cdec_tb_top.clk),
    .instr_i         (instr_i),
    .instr_o         (instr_o),
    .is_compressed_o (is_compressed_o),
    .illegal_instr_o (illegal_instr_o)
);
