`include "rv32i_defines.vh"
class If_Scoreboard;
    mailbox #(If_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;
    int instr_count = 0;
    int comp_count  = 0;
    int set_count   = 0;

    logic [31:0] pc;
    bit          started;
    bit          exp_valid_id;
    bit          pending;
    logic [31:0] p_instr;
    logic        p_comp;
    logic        p_ill;
    logic [31:0] p_pc;

    function new(mailbox #(If_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        started      = 0;
        exp_valid_id = 0;
        pending      = 0;
    endfunction

    function logic [31:0] enc_i(logic [11:0] imm, logic [4:0] rs1, logic [2:0] f3, logic [4:0] rd, logic [6:0] opc);
        return {imm, rs1, f3, rd, opc};
    endfunction

    function logic [31:0] enc_s(logic [11:0] imm, logic [4:0] rs2, logic [4:0] rs1, logic [2:0] f3);
        return {imm[11:5], rs2, rs1, f3, imm[4:0], `OPCODE_STORE};
    endfunction

    function logic [31:0] enc_b(logic [12:0] imm, logic [4:0] rs2, logic [4:0] rs1, logic [2:0] f3);
        return {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], `OPCODE_BRANCH};
    endfunction

    function logic [31:0] enc_j(logic [20:0] imm, logic [4:0] rd);
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, `OPCODE_JAL};
    endfunction

    function logic [31:0] enc_u(logic [19:0] imm, logic [4:0] rd);
        return {imm, rd, `OPCODE_LUI};
    endfunction

    function logic [31:0] enc_r(logic [6:0] f7, logic [4:0] rs2, logic [4:0] rs1, logic [2:0] f3, logic [4:0] rd);
        return {f7, rs2, rs1, f3, rd, `OPCODE_OP};
    endfunction

    function void expand(logic [15:0] c, output logic [31:0] instr, output logic illegal);
        logic [4:0]  rd, rs2, rdp, rs1p, rs2p;
        logic [5:0]  imm6;
        logic [11:0] imm12;
        logic [12:0] boff;
        logic [20:0] joff;
        logic [9:0]  uimm;
        rd    = c[11:7];
        rs2   = c[6:2];
        rdp   = {2'b01, c[4:2]};
        rs1p  = {2'b01, c[9:7]};
        rs2p  = {2'b01, c[4:2]};
        imm6  = {c[12], c[6:2]};
        imm12 = {{6{c[12]}}, c[12], c[6:2]};
        boff  = {{5{c[12]}}, c[6:5], c[2], c[11:10], c[4:3], 1'b0};
        joff  = {{10{c[12]}}, c[8], c[10:9], c[6], c[7], c[2], c[11], c[5:3], 1'b0};
        instr   = 32'h0;
        illegal = 1'b0;
        case ({c[1:0], c[15:13]})
            5'b00_000: begin
                uimm    = {c[10:7], c[12:11], c[5], c[6], 2'b00};
                instr   = enc_i({2'b00, uimm}, 5'd2, 3'b000, rdp, `OPCODE_OPIMM);
                illegal = (uimm == 10'h0);
            end
            5'b00_010: instr = enc_i({5'b0, c[5], c[12:10], c[6], 2'b00}, rs1p, 3'b010, rdp, `OPCODE_LOAD);
            5'b00_110: instr = enc_s({5'b0, c[5], c[12:10], c[6], 2'b00}, rs2p, rs1p, 3'b010);
            5'b01_000: instr = enc_i(imm12, rd, 3'b000, rd, `OPCODE_OPIMM);
            5'b01_001: instr = enc_j(joff, 5'd1);
            5'b01_101: instr = enc_j(joff, 5'd0);
            5'b01_010: begin
                instr   = enc_i(imm12, 5'd0, 3'b000, rd, `OPCODE_OPIMM);
                illegal = (rd == 5'd0);
            end
            5'b01_011: begin
                if (rd == 5'd2)
                    instr = enc_i({{3{c[12]}}, c[4:3], c[5], c[2], c[6], 4'b0}, 5'd2, 3'b000, 5'd2, `OPCODE_OPIMM);
                else
                    instr = enc_u({{14{c[12]}}, c[12], c[6:2]}, rd);
                illegal = (imm6 == 6'h0) || (rd == 5'd0);
            end
            5'b01_100: begin
                case (c[11:10])
                    2'b00: begin
                        instr   = enc_i({7'b0000000, c[6:2]}, rs1p, 3'b101, rs1p, `OPCODE_OPIMM);
                        illegal = c[12] || (c[6:2] == 5'd0);
                    end
                    2'b01: begin
                        instr   = enc_i({7'b0100000, c[6:2]}, rs1p, 3'b101, rs1p, `OPCODE_OPIMM);
                        illegal = c[12] || (c[6:2] == 5'd0);
                    end
                    2'b10: instr = enc_i(imm12, rs1p, 3'b111, rs1p, `OPCODE_OPIMM);
                    2'b11: begin
                        case ({c[12], c[6:5]})
                            3'b000: instr = enc_r(7'b0100000, rs2p, rs1p, 3'b000, rs1p);
                            3'b001: instr = enc_r(7'b0000000, rs2p, rs1p, 3'b100, rs1p);
                            3'b010: instr = enc_r(7'b0000000, rs2p, rs1p, 3'b110, rs1p);
                            3'b011: instr = enc_r(7'b0000000, rs2p, rs1p, 3'b111, rs1p);
                            default: illegal = 1'b1;
                        endcase
                    end
                endcase
            end
            5'b01_110: instr = enc_b(boff, 5'd0, rs1p, 3'b000);
            5'b01_111: instr = enc_b(boff, 5'd0, rs1p, 3'b001);
            5'b10_000: begin
                instr   = enc_i({7'b0000000, c[6:2]}, rd, 3'b001, rd, `OPCODE_OPIMM);
                illegal = (rd == 5'd0) || c[12] || (c[6:2] == 5'd0);
            end
            5'b10_010: begin
                instr   = enc_i({4'b0, c[3:2], c[12], c[6:4], 2'b00}, 5'd2, 3'b010, rd, `OPCODE_LOAD);
                illegal = (rd == 5'd0);
            end
            5'b10_100: begin
                if (!c[12]) begin
                    if (rs2 == 5'd0) begin
                        instr   = enc_i(12'h0, rd, 3'b000, 5'd0, `OPCODE_JALR);
                        illegal = (rd == 5'd0);
                    end else
                        instr = enc_r(7'b0, rs2, 5'd0, 3'b000, rd);
                end else begin
                    if (rd == 5'd0) begin
                        instr   = 32'h0010_0073;
                        illegal = (rs2 != 5'd0);
                    end else if (rs2 == 5'd0)
                        instr = enc_i(12'h0, rd, 3'b000, 5'd1, `OPCODE_JALR);
                    else
                        instr = enc_r(7'b0, rs2, rd, 3'b000, rd);
                end
            end
            5'b10_110: instr = enc_s({4'b0, c[8:7], c[12], c[11:9], 2'b00}, rs2, 5'd2, 3'b010);
            default: illegal = 1'b1;
        endcase
    endfunction

    function logic [15:0] mem_hw(logic [31:0] addr);
        logic [31:0] w;
        w = If_Transaction::mem_word(addr);
        return addr[1] ? w[31:16] : w[15:0];
    endfunction

    function logic [31:0] target(If_Transaction t);
        logic [31:0] exc_pc;
        case (t.exc_pc_mux_i)
            `EXC_PC_ILLINSN: exc_pc = {t.boot_addr_i[31:8], `EXC_OFF_ILLINSN};
            `EXC_PC_ECALL:   exc_pc = {t.boot_addr_i[31:8], `EXC_OFF_ECALL};
            `EXC_PC_IRQ:     exc_pc = {t.boot_addr_i[31:8], 1'b0, t.exc_vec_pc_mux_i, 2'b00};
            default:         exc_pc = 32'h0;
        endcase
        case (t.pc_mux_i)
            `PC_BOOT:      return {t.boot_addr_i[31:8], `EXC_OFF_RST};
            `PC_JUMP:      return t.jump_target_ex_i;
            `PC_EXCEPTION: return exc_pc;
            `PC_ERET:      return t.exception_pc_reg_i;
            `PC_DBG_NPC:   return t.dbg_jump_addr_i;
            default:       return 32'h0;
        endcase
    endfunction

    task run();
        If_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(If_Transaction t);
        string       diff;
        bit          branch;
        logic [15:0] h0, h1;
        logic [31:0] instr;
        logic        ill;
        logic [31:0] tgt;
        bit          comp;
        diff = "";

        if (t.instr_valid_id_o !== exp_valid_id)
            diff = {diff, $sformatf(" instr_valid_id exp=%b got=%b", exp_valid_id, t.instr_valid_id_o)};
        if (pending) begin
            if (t.pc_id_o !== p_pc)
                diff = {diff, $sformatf(" pc_id exp=%h got=%h", p_pc, t.pc_id_o)};
            if (t.is_compressed_id_o !== p_comp)
                diff = {diff, $sformatf(" is_compressed exp=%b got=%b", p_comp, t.is_compressed_id_o)};
            if (t.illegal_c_insn_id_o !== p_ill)
                diff = {diff, $sformatf(" illegal_c exp=%b got=%b", p_ill, t.illegal_c_insn_id_o)};
            if (!p_ill && t.instr_rdata_id_o !== p_instr)
                diff = {diff, $sformatf(" instr_rdata_id exp=%h got=%h", p_instr, t.instr_rdata_id_o)};
        end
        pending = 0;

        branch = t.pc_set_i || (!started && t.req_i);
        if (branch) begin
            tgt     = target(t);
            pc      = {tgt[31:1], 1'b0};
            started = 1;
            set_count++;
            if (t.if_valid_o === 1'b1)
                diff = {diff, " if_valid during pc_set"};
        end else if (t.if_valid_o === 1'b1) begin
            if (t.halt_if_i || !t.id_ready_i)
                diff = {diff, " if_valid while halted or ID not ready"};
            if (t.pc_if_o !== pc)
                diff = {diff, $sformatf(" pc_if exp=%h got=%h", pc, t.pc_if_o)};
            h0   = mem_hw(pc);
            h1   = mem_hw(pc + 32'h2);
            comp = (h0[1:0] != 2'b11);
            if (comp)
                expand(h0, instr, ill);
            else begin
                instr = {h1, h0};
                ill   = 1'b0;
            end
            pending = 1;
            p_instr = instr;
            p_comp  = comp;
            p_ill   = ill;
            p_pc    = pc;
            instr_count++;
            if (comp) comp_count++;
            pc = pc + (comp ? 32'h2 : 32'h4);
        end

        if (t.if_valid_o === 1'b1)
            exp_valid_id = 1;
        else if (t.clear_instr_valid_i)
            exp_valid_id = 0;

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH pc=%h pc_set=%b mux=%0d :%s", pc, t.pc_set_i, t.pc_mux_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d instructions=%0d compressed=%0d pc_sets=%0d",
                 total_count, pass_count, fail_count, instr_count, comp_count, set_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0 && instr_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
