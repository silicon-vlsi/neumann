class Decoder_Coverage;
    mailbox #(Decoder_Transaction) mon2cov;
    Decoder_Transaction tx;

    logic [6:0]               opcode;
    logic [2:0]               funct3;
    logic [6:0]               funct7;
    logic [11:0]              imm12;
    logic                     deassert_we_i;
    logic                     data_misaligned_i;
    logic                     branch_mux_i;
    logic                     jump_mux_i;
    logic                     illegal_c_insn_i;
    logic                     illegal_insn_o;
    logic [`ALU_OP_WIDTH-1:0] alu_operator_o;
    logic [3:0]               imm_b_mux_sel_o;
    logic [1:0]               csr_op_o;
    logic                     csr_status_o;
    logic [1:0]               data_type_o;
    logic                     data_sign_extension_o;
    logic                     data_load_event_o;

    covergroup cg;
        option.per_instance = 1;

        cp_opcode : coverpoint opcode {
            bins lui    = {`OPCODE_LUI};
            bins auipc  = {`OPCODE_AUIPC};
            bins jal    = {`OPCODE_JAL};
            bins jalr   = {`OPCODE_JALR};
            bins branch = {`OPCODE_BRANCH};
            bins load   = {`OPCODE_LOAD};
            bins store  = {`OPCODE_STORE};
            bins opimm  = {`OPCODE_OPIMM};
            bins op     = {`OPCODE_OP};
            bins system = {`OPCODE_SYSTEM};
            bins fence  = {`OPCODE_FENCE};
            bins others = default;
        }

        cp_dwe   : coverpoint deassert_we_i     { bins off = {0}; bins on = {1}; }
        cp_mis   : coverpoint data_misaligned_i { bins off = {0}; bins on = {1}; }
        cp_bmux  : coverpoint branch_mux_i      { bins off = {0}; bins on = {1}; }
        cp_jmux  : coverpoint jump_mux_i        { bins off = {0}; bins on = {1}; }
        cp_ill_c : coverpoint illegal_c_insn_i  { bins off = {0}; bins on = {1}; }

        cp_illegal : coverpoint illegal_insn_o {
            bins legal   = {0};
            bins illegal = {1};
        }

        cp_branch_f3 : coverpoint funct3 iff (opcode == `OPCODE_BRANCH) {
            bins beq = {3'b000}; bins bne  = {3'b001};
            bins blt = {3'b100}; bins bge  = {3'b101};
            bins bltu= {3'b110}; bins bgeu = {3'b111};
            bins bad = {3'b010, 3'b011};
        }
        cp_load_f3 : coverpoint funct3 iff (opcode == `OPCODE_LOAD) {
            bins lb  = {3'b000}; bins lh  = {3'b001}; bins lw = {3'b010};
            bins lbu = {3'b100}; bins lhu = {3'b101};
            bins ld  = {3'b011}; bins elw = {3'b110}; bins rr = {3'b111};
        }
        cp_store_f3 : coverpoint funct3 iff (opcode == `OPCODE_STORE) {
            bins sb  = {3'b000}; bins sh = {3'b001}; bins sw = {3'b010};
            bins bad = {3'b011, [3'b100:3'b111]};
        }
        cp_opimm_f3 : coverpoint funct3 iff (opcode == `OPCODE_OPIMM) {
            bins addi = {3'b000}; bins slli  = {3'b001};
            bins slti = {3'b010}; bins sltiu = {3'b011};
            bins xori = {3'b100}; bins sr    = {3'b101};
            bins ori  = {3'b110}; bins andi  = {3'b111};
        }
        cp_op_rr : coverpoint {funct7, funct3} iff (opcode == `OPCODE_OP) {
            bins add  = {10'b0000000_000}; bins sub  = {10'b0100000_000};
            bins sll  = {10'b0000000_001}; bins slt  = {10'b0000000_010};
            bins sltu = {10'b0000000_011}; bins xor_ = {10'b0000000_100};
            bins srl  = {10'b0000000_101}; bins sra  = {10'b0100000_101};
            bins or_  = {10'b0000000_110}; bins and_ = {10'b0000000_111};
            bins bad  = default;
        }
        cp_system : coverpoint imm12 iff (opcode == `OPCODE_SYSTEM && funct3 == 3'b000) {
            bins ecall  = {12'h000};
            bins ebreak = {12'h001};
            bins mret   = {12'h302};
            bins wfi    = {12'h105};
            bins bad    = default;
        }
        cp_csr_f3 : coverpoint funct3 iff (opcode == `OPCODE_SYSTEM && funct3 != 3'b000) {
            bins csrrw  = {3'b001}; bins csrrs  = {3'b010}; bins csrrc  = {3'b011};
            bins csrrwi = {3'b101}; bins csrrsi = {3'b110}; bins csrrci = {3'b111};
            bins bad    = {3'b100};
        }

        cp_alu_op : coverpoint alu_operator_o {
            bins add  = {`ALU_ADD};  bins sub  = {`ALU_SUB};
            bins xor_ = {`ALU_XOR};  bins or_  = {`ALU_OR};  bins and_ = {`ALU_AND};
            bins sll  = {`ALU_SLL};  bins srl  = {`ALU_SRL}; bins sra  = {`ALU_SRA};
            bins slts = {`ALU_SLTS}; bins sltu = {`ALU_SLTU};
            bins eq   = {`ALU_EQ};   bins ne   = {`ALU_NE};
            bins lts  = {`ALU_LTS};  bins ges  = {`ALU_GES};
            bins ltu  = {`ALU_LTU};  bins geu  = {`ALU_GEU};
        }
        cp_imm_b : coverpoint imm_b_mux_sel_o {
            bins i      = {`IMMB_I};  bins s  = {`IMMB_S};  bins u  = {`IMMB_U};
            bins pcincr = {`IMMB_PCINCR};
            bins uj     = {`IMMB_UJ}; bins sb = {`IMMB_SB};
        }
        cp_csr_op : coverpoint csr_op_o {
            bins none = {`CSR_OP_NONE};  bins write = {`CSR_OP_WRITE};
            bins set  = {`CSR_OP_SET};   bins clear = {`CSR_OP_CLEAR};
        }
        cp_csr_status : coverpoint csr_status_o { bins off = {0}; bins on = {1}; }
        cp_load_ev    : coverpoint data_load_event_o { bins off = {0}; bins on = {1}; }
        cp_dtype      : coverpoint data_type_o iff (opcode inside {`OPCODE_LOAD, `OPCODE_STORE}) {
            bins word = {2'b00}; bins half = {2'b01}; bins byte_ = {2'b10};
        }
        cp_sext : coverpoint data_sign_extension_o iff (opcode == `OPCODE_LOAD) {
            bins zero_ext = {0}; bins sign_ext = {1};
        }

        x_op_dwe : cross cp_opcode, cp_dwe;
        x_op_mis : cross cp_opcode, cp_mis;
        x_op_ill_c : cross cp_opcode, cp_ill_c;
        x_op_jmux : cross cp_opcode, cp_jmux {
            ignore_bins not_jump = !binsof(cp_opcode) intersect {`OPCODE_JAL, `OPCODE_JALR};
        }
        x_op_bmux : cross cp_opcode, cp_bmux {
            ignore_bins not_branch = !binsof(cp_opcode) intersect {`OPCODE_BRANCH};
        }
    endgroup

    function new(mailbox #(Decoder_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            opcode                = tx.instr_rdata_i[6:0];
            funct3                = tx.instr_rdata_i[14:12];
            funct7                = tx.instr_rdata_i[31:25];
            imm12                 = tx.instr_rdata_i[31:20];
            deassert_we_i         = tx.deassert_we_i;
            data_misaligned_i     = tx.data_misaligned_i;
            branch_mux_i          = tx.branch_mux_i;
            jump_mux_i            = tx.jump_mux_i;
            illegal_c_insn_i      = tx.illegal_c_insn_i;
            illegal_insn_o        = tx.illegal_insn_o;
            alu_operator_o        = tx.alu_operator_o;
            imm_b_mux_sel_o       = tx.imm_b_mux_sel_o;
            csr_op_o              = tx.csr_op_o;
            csr_status_o          = tx.csr_status_o;
            data_type_o           = tx.data_type_o;
            data_sign_extension_o = tx.data_sign_extension_o;
            data_load_event_o     = tx.data_load_event_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
