interface imm_interface;
logic [31:0] instr_i;
logic [3:0] imm_sel_i;
logic [31:0] imm_o;
modport DRV(output instr_i,output imm_sel_i);
modport MON(input imm_sel_i,input imm_o, input instr_i);
endinterface