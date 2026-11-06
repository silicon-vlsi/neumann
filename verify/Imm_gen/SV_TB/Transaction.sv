class Transaction;
rand logic [31:0] instr_i;
rand logic [3:0] imm_sel_i;
logic [31:0] imm_o;

constraint imm_sel_I2U {imm_sel_i inside {[4'b0000:4'b1101]};}

function void display(string tag="Transaction");
$display("[%s] instr_i = %0b, imm_sel_i = %0b, imm_o = %0b",tag, instr_i, imm_sel_i, imm_o);    
endfunction

endclass

