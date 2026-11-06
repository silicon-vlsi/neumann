`include "rv32i_defines.vh"
class Cdec_Scoreboard;
    mailbox #(Cdec_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;
    int illegal_count = 0;

    function new(mailbox #(Cdec_Transaction) mon2scb);
        this.mon2scb = mon2scb;
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

    task run();
        Cdec_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            check(tx);
        end
    endtask

    function void check(Cdec_Transaction tx);
        logic [31:0] exp_instr;
        logic        exp_illegal;
        logic        exp_comp;
        string       diff;
        diff     = "";
        exp_comp = (tx.instr_i[1:0] != 2'b11);
        if (exp_comp)
            expand(tx.instr_i[15:0], exp_instr, exp_illegal);
        else begin
            exp_instr   = tx.instr_i;
            exp_illegal = 1'b0;
        end
        if (exp_illegal)
            illegal_count++;

        if (tx.is_compressed_o !== exp_comp)
            diff = {diff, $sformatf(" is_compressed exp=%b got=%b", exp_comp, tx.is_compressed_o)};
        if (tx.illegal_instr_o !== exp_illegal)
            diff = {diff, $sformatf(" illegal exp=%b got=%b", exp_illegal, tx.illegal_instr_o)};
        if (!exp_illegal && tx.instr_o !== exp_instr)
            diff = {diff, $sformatf(" instr_o exp=%h got=%h", exp_instr, tx.instr_o)};

        if (diff == "")
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH instr_i=%h :%s", tx.instr_i, diff);
        end
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d illegal=%0d",
                 total_count, pass_count, fail_count, illegal_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
