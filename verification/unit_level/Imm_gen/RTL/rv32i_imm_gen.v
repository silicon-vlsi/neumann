`include "rv32i_defines.vh"
module rv32i_imm_gen
(
    input  [31:0] instr_i,      // full instruction
    input  [3:0]  imm_sel_i,    // immediate type from decoder
    output reg [31:0] imm_o     // 32-bit sign extended immediate
);
    always @(*) begin
        case (imm_sel_i)
            `IMMB_I: 
            begin
                // I-type — loads, ADDI, JALR
                // bits [31:20] sign extended to 32 bits
                imm_o = { {20{instr_i[31]}}, instr_i[31:20] };
            end
            `IMMB_S: 
            begin
                // S-type — stores
                // bits [31:25] and [11:7]
                imm_o = { {20{instr_i[31]}}, instr_i[31:25], instr_i[11:7] };
            end
            `IMMB_SB: 
            begin
                // B-type — branches
                // bits [31][7][30:25][11:8] with LSB = 0
                imm_o = { {19{instr_i[31]}}, instr_i[31], instr_i[7],instr_i[30:25], instr_i[11:8], 1'b0 };
            end
            `IMMB_U: 
            begin
                // U-type — LUI, AUIPC
                // upper 20 bits, lower 12 = 0
                imm_o = { instr_i[31:12], 12'b0 };
            end
            `IMMB_UJ: 
            begin
                // J-type — JAL
                // bits [31][19:12][20][30:21] with LSB = 0
                imm_o = { {12{instr_i[31]}}, instr_i[19:12], instr_i[20],
                           instr_i[30:21], 1'b0 };
            end
            `IMMB_PCINCR: 
            begin
             imm_o = 32'd4;
            end
            default: begin
                imm_o = 32'b0;
            end
        endcase
    end
endmodule