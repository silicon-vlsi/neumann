`include "rv32i_defines.vh"
module rv32i_decoder
(
  input deassert_we_i,          // deassert we; stalled or not active
  input data_misaligned_i,      // misaligned data load/store in progress
  input branch_mux_i,           // branch mux select from FSM
  input jump_mux_i,             // jump mux select from FSM
  output reg illegal_insn_o,         // illegal instruction encountered
  output reg ebrk_insn_o,            // EBREAK instruction
  output reg mret_insn_o,            // MRET instruction
  output reg ecall_insn_o,           // ECALL instruction
  output reg pipe_flush_o,           // pipeline flush requested (WFI)
  input  [31:0] instr_rdata_i,
  input  illegal_c_insn_i,       // compressed instruction decode failed
  // ALU signals
  output reg  [`ALU_OP_WIDTH-1:0] alu_operator_o,   // ALU operation select
  output reg  [2:0]  alu_op_a_mux_sel_o,    // operand A select
  output reg  [2:0]  alu_op_b_mux_sel_o,    // operand B select 
  output reg  imm_a_mux_sel_o,       // immediate select for operand A
  output reg  [3:0]  imm_b_mux_sel_o,       // immediate select for operand B
  // Register file
  output regfile_we_o,           // register file write enable
  // CSR manipulation
  output reg csr_access_o,           // CSR access
  output [1:0]  csr_op_o,               // CSR operation
  output reg csr_status_o,           // mstatus CSR access
  // Load/Store unit signals
  output data_req_o,             // data memory request
  output reg data_we_o,              // data memory write enable
  output reg  [1:0]  data_type_o,            // byte / half-word / word
  output reg data_sign_extension_o,  // sign extension on load
  output reg  [1:0]  data_reg_offset_o,      // byte offset for stores
  output reg data_load_event_o,      // p.elw special event load
  // Jump / Branch
  output jump_in_id_o,           // jump being calculated in ID
  output branch_in_id_o          // branch in ID
);
  // Internal registers (combinational decode results before deassert gating)
  reg regfile_we;
  reg data_req;
  reg branch_in_id;
  reg jump_in_id;
  reg  [1:0] csr_op;
  reg csr_illegal;
  always @(*)
  begin
    // ----- Default / safe values -----
    jump_in_id = 1'b0;
    branch_in_id = 1'b0;
    alu_operator_o = `ALU_SLTU;
    alu_op_a_mux_sel_o = `OP_A_REGA_OR_FWD;
    alu_op_b_mux_sel_o = `OP_B_REGB_OR_FWD;
    imm_a_mux_sel_o = `IMMA_ZERO;
    imm_b_mux_sel_o = `IMMB_I;
    regfile_we = 1'b0;
    csr_access_o = 1'b0;
    csr_status_o = 1'b0;
    csr_illegal  = 1'b0;
    csr_op = `CSR_OP_NONE;
    data_we_o = 1'b0;
    data_type_o = 2'b00;
    data_sign_extension_o = 1'b0;
    data_reg_offset_o = 2'b00;
    data_req = 1'b0;
    data_load_event_o = 1'b0;
    illegal_insn_o = 1'b0;
    ebrk_insn_o  = 1'b0;
    mret_insn_o  = 1'b0;
    ecall_insn_o = 1'b0;
    pipe_flush_o = 1'b0;
    // ----- Opcode decode -----
    case (instr_rdata_i[6:0])
      `OPCODE_JAL: 
      begin   // Jump and Link
        jump_in_id = 1'b1;
        if (jump_mux_i) 
        begin
          // Calculate jump target: PC + UJ-imm
          alu_op_a_mux_sel_o = `OP_A_CURRPC;
          alu_op_b_mux_sel_o = `OP_B_IMM;
          imm_b_mux_sel_o = `IMMB_UJ;
          alu_operator_o = `ALU_ADD;
          regfile_we = 1'b0;
        end 
        else 
        begin
          // Calculate and store PC+4 into rd
          alu_op_a_mux_sel_o = `OP_A_CURRPC;
          alu_op_b_mux_sel_o = `OP_B_IMM;
          imm_b_mux_sel_o = `IMMB_PCINCR;
          alu_operator_o = `ALU_ADD;
          regfile_we = 1'b1;
        end
      end
      `OPCODE_JALR: 
      begin  // Jump and Link Register
        jump_in_id = 1'b1;
        if (jump_mux_i) 
        begin
          // Calculate jump target: rs1 + I-imm
          alu_op_a_mux_sel_o = `OP_A_REGA_OR_FWD;
          alu_op_b_mux_sel_o = `OP_B_IMM;
          imm_b_mux_sel_o = `IMMB_I;
          alu_operator_o = `ALU_ADD;
          regfile_we = 1'b0;
        end 
        else 
        begin
          // Calculate and store PC+4 into rd
          alu_op_a_mux_sel_o = `OP_A_CURRPC;
          alu_op_b_mux_sel_o = `OP_B_IMM;
          imm_b_mux_sel_o    = `IMMB_PCINCR;
          alu_operator_o     = `ALU_ADD;
          regfile_we         = 1'b1;
        end
        // funct3 must be 3'b000
        if (instr_rdata_i[14:12] != 3'b000) 
        begin
          jump_in_id     = 1'b0;
          regfile_we     = 1'b0;
          illegal_insn_o = 1'b1;
        end
      end
      `OPCODE_BRANCH: 
      begin // Conditional Branch
        branch_in_id = 1'b1;
        if (branch_mux_i) 
        begin
          // Select comparison operation
          case (instr_rdata_i[14:12])
            3'b000: alu_operator_o = `ALU_EQ;
            3'b001: alu_operator_o = `ALU_NE;
            3'b100: alu_operator_o = `ALU_LTS;
            3'b101: alu_operator_o = `ALU_GES;
            3'b110: alu_operator_o = `ALU_LTU;
            3'b111: alu_operator_o = `ALU_GEU;
            default: 
            begin
               illegal_insn_o = 1'b1;
            end
          endcase
        end 
        else 
        begin
          // Calculate branch target: PC + SB-imm
          alu_op_a_mux_sel_o = `OP_A_CURRPC;
          alu_op_b_mux_sel_o = `OP_B_IMM;
          imm_b_mux_sel_o    = `IMMB_SB;
          alu_operator_o     = `ALU_ADD;
          regfile_we         = 1'b0;
        end
      end
      `OPCODE_STORE: 
      begin
        data_req       = 1'b1;
        data_we_o      = 1'b1;
        alu_operator_o = `ALU_ADD;
        if (instr_rdata_i[14] == 1'b0)
        begin
          // Immediate offset (S-type)
          imm_b_mux_sel_o    = `IMMB_S;
          alu_op_b_mux_sel_o = `OP_B_IMM;
        end 
        else 
        begin
          // Register offset is illegal (no register C in RV32I store)
          data_req       = 1'b0;
          data_we_o      = 1'b0;
          illegal_insn_o = 1'b1;
        end
        // Store width: bits [13:12]
        case (instr_rdata_i[13:12])
          2'b00:   data_type_o = 2'b10;  // SB
          2'b01:   data_type_o = 2'b01;  // SH
          2'b10:   data_type_o = 2'b00;  // SW
          default: 
          begin
            data_req       = 1'b0;
            data_we_o      = 1'b0;
            illegal_insn_o = 1'b1;
          end
        endcase
      end
      `OPCODE_LOAD: 
      begin
        data_req   = 1'b1;
        regfile_we = 1'b1;
        data_type_o = 2'b00;
        // Offset from I-immediate
        alu_operator_o = `ALU_ADD;
        alu_op_b_mux_sel_o = `OP_B_IMM;
        imm_b_mux_sel_o = `IMMB_I;
        // Sign/zero extension: bit[14] = 0 → signed, 1 → unsigned
        data_sign_extension_o = ~instr_rdata_i[14];
        // Load width
        case (instr_rdata_i[13:12])
          2'b00:   data_type_o = 2'b10;  // LB / LBU
          2'b01:   data_type_o = 2'b01;  // LH / LHU
          2'b10:   data_type_o = 2'b00;  // LW
          default: data_type_o = 2'b00;  // illegal / reg-reg
        endcase
        // Register-register load (instr_rdata_i[14:12] == 3'b111, custom encoding)
        if (instr_rdata_i[14:12] == 3'b111) 
        begin
          alu_op_b_mux_sel_o    = `OP_B_REGB_OR_FWD;
          data_sign_extension_o = ~instr_rdata_i[30];
          case (instr_rdata_i[31:25])
            7'b000_0000: data_type_o = 2'b10;
            7'b010_0000: data_type_o = 2'b10;  // LB, LBU
            7'b000_1000: data_type_o = 2'b01;
            7'b010_1000: data_type_o = 2'b01;  // LH, LHU
            7'b001_0000: data_type_o = 2'b00;  // LW
            default:illegal_insn_o = 1'b1;
          endcase
        end
        // Special p.elw (event load, funct3 == 3'b110)
        if (instr_rdata_i[14:12] == 3'b110)
          data_load_event_o = 1'b1;
        // LD (instr_rdata_i[14:12] == 3'b011) is RV64 only
        if (instr_rdata_i[14:12] == 3'b011)
          illegal_insn_o = 1'b1;
      end
      `OPCODE_LUI: 
      begin  // Load Upper Immediate
        alu_op_a_mux_sel_o = `OP_A_IMM;
        alu_op_b_mux_sel_o = `OP_B_IMM;
        imm_a_mux_sel_o    = `IMMA_ZERO;
        imm_b_mux_sel_o    = `IMMB_U;
        alu_operator_o     = `ALU_ADD;
        regfile_we         = 1'b1;
      end
      `OPCODE_AUIPC: 
      begin  // Add Upper Immediate to PC
        alu_op_a_mux_sel_o = `OP_A_CURRPC;
        alu_op_b_mux_sel_o = `OP_B_IMM;
        imm_b_mux_sel_o    = `IMMB_U;
        alu_operator_o     = `ALU_ADD;
        regfile_we         = 1'b1;
      end
      `OPCODE_OPIMM: 
      begin  // Register-Immediate ALU operations
        alu_op_b_mux_sel_o = `OP_B_IMM;
        imm_b_mux_sel_o    = `IMMB_I;
        regfile_we         = 1'b1;
 
        case (instr_rdata_i[14:12])
          3'b000: alu_operator_o = `ALU_ADD;   // ADDI
          3'b010: alu_operator_o = `ALU_SLTS;  // SLTI
          3'b011: alu_operator_o = `ALU_SLTU;  // SLTIU
          3'b100: alu_operator_o = `ALU_XOR;   // XORI
          3'b110: alu_operator_o = `ALU_OR;    // ORI
          3'b111: alu_operator_o = `ALU_AND;   // ANDI
          3'b001: 
          begin              // SLLI
            alu_operator_o = `ALU_SLL;
            if (instr_rdata_i[31:25] != 7'b000_0000)
            illegal_insn_o = 1'b1;
          end
          3'b101: 
          begin
            if (instr_rdata_i[31:25] == 7'b000_0000)
              alu_operator_o = `ALU_SRL;        // SRLI
            else if (instr_rdata_i[31:25] == 7'b010_0000)
              alu_operator_o = `ALU_SRA;        // SRAI
            else
              illegal_insn_o = 1'b1;
          end
          default: illegal_insn_o = 1'b1;
        endcase
      end
      `OPCODE_OP: 
      begin  // Register-Register ALU operations
        regfile_we = 1'b1;
        if (instr_rdata_i[31]) 
        begin
          // bit[31] == 1 is always illegal in RV32I/M
          illegal_insn_o = 1'b1;
        end 
        else 
        begin
          if (~instr_rdata_i[28]) 
          begin
            // Standard RV32I and RV32M (bit28 = 0)
            case ({instr_rdata_i[30:25], instr_rdata_i[14:12]})
               // ---- RV32I ALU ----
              10'b00_0000_000: alu_operator_o = `ALU_ADD;   // ADD
              10'b10_0000_000: alu_operator_o = `ALU_SUB;   // SUB
              10'b00_0000_010: alu_operator_o = `ALU_SLTS;  // SLT
              10'b00_0000_011: alu_operator_o = `ALU_SLTU;  // SLTU
              10'b00_0000_100: alu_operator_o = `ALU_XOR;   // XOR
              10'b00_0000_110: alu_operator_o = `ALU_OR;    // OR
              10'b00_0000_111: alu_operator_o = `ALU_AND;   // AND
              10'b00_0000_001: alu_operator_o = `ALU_SLL;   // SLL
              10'b00_0000_101: alu_operator_o = `ALU_SRL;   // SRL
              10'b10_0000_101: alu_operator_o = `ALU_SRA;   // SRA
              default: illegal_insn_o = 1'b1;
            endcase
          end
          // bit28 == 1: custom / bit-manipulation (not implemented → illegal)
          else 
          begin
            illegal_insn_o = 1'b1;
          end
        end
      end
      `OPCODE_SYSTEM: 
      begin
        if (instr_rdata_i[14:12] == 3'b000) 
        begin
          // Non-CSR SYSTEM instructions; encoded in bits [31:20]
          case (instr_rdata_i[31:20])
            12'h000: 
            begin  // ECALL
              ecall_insn_o = 1'b1;
            end
            12'h001: 
            begin  // EBREAK
              ebrk_insn_o  = 1'b1;
            end
            12'h302: 
            begin  // MRET
              mret_insn_o  = 1'b1;
            end
            12'h105: 
            begin  // WFI  →  flush pipeline
              pipe_flush_o = 1'b1;
            end
            default: 
            begin
              illegal_insn_o = 1'b1;
            end
          endcase
        end 
        else 
        begin
          // CSR read/modify instructions
          csr_access_o       = 1'b1;
          regfile_we         = 1'b1;
          alu_op_b_mux_sel_o = `OP_B_IMM;
          imm_a_mux_sel_o    = `IMMA_Z;
          imm_b_mux_sel_o    = `IMMB_I;   // CSR address encoded in I-imm
          // bit[14]: 1 → rs1 used as immediate (CSRRWI/CSRRSI/CSRRCI)
          if (instr_rdata_i[14])
            alu_op_a_mux_sel_o = `OP_A_IMM;
          else
            alu_op_a_mux_sel_o = `OP_A_REGA_OR_FWD;
          case (instr_rdata_i[13:12])
            2'b01:   csr_op = `CSR_OP_WRITE;
            2'b10:   csr_op = `CSR_OP_SET;
            2'b11:   csr_op = `CSR_OP_CLEAR;
            default: csr_illegal = 1'b1;
          endcase
          // mstatus (0x300) access flag
          if (~csr_illegal) 
          begin
            if (instr_rdata_i[31:20] == 12'h300)
              csr_status_o = 1'b1;
          end
          illegal_insn_o = csr_illegal;
        end
      end
      default: begin
        illegal_insn_o = 1'b1;
      end
    endcase // opcode
    //------------------------------------------------------------------------
    // Override: illegal compressed instruction always raises exception
    //------------------------------------------------------------------------
    if (illegal_c_insn_i)
      illegal_insn_o = 1'b1;
    //------------------------------------------------------------------------
    // Override: misaligned LSU access detected
    // Only part of the pipeline unstalled; force correct AGU operands
    //------------------------------------------------------------------------
    if (data_misaligned_i) 
    begin
      alu_op_a_mux_sel_o = `OP_A_REGA_OR_FWD;
      alu_op_b_mux_sel_o = `OP_B_IMM;
      imm_b_mux_sel_o    = `IMMB_PCINCR;
      // No writeback for the second misaligned access
      regfile_we = 1'b0;
    end
  end 
  // Deassert gating: suppress write-enable / request signals during stalls
  assign regfile_we_o =(deassert_we_i) ? 1'b0 : regfile_we;
  assign data_req_o =(deassert_we_i) ? 1'b0 : data_req;
  assign csr_op_o =(deassert_we_i) ? `CSR_OP_NONE : csr_op;
  assign jump_in_id_o =(deassert_we_i) ? 1'b0 : jump_in_id;
  assign branch_in_id_o =(deassert_we_i) ? 1'b0 : branch_in_id;
endmodule