`include "rv32i_defines.vh"
class If_Transaction;
    rand logic req_i;
    rand logic clear_instr_valid_i;
    rand logic pc_set_i;
    rand logic [31:0] exception_pc_reg_i;
    rand logic [2:0] pc_mux_i;
    rand logic [1:0] exc_pc_mux_i;
    rand logic [4:0] exc_vec_pc_mux_i;
    rand logic [31:0] jump_target_ex_i;
    rand logic [31:0] dbg_jump_addr_i;
    rand logic halt_if_i;
    rand logic id_ready_i;
    rand logic        instr_gnt_i;
    rand int unsigned lat;

    logic rst_n;
    logic [31:0] boot_addr_i;
    logic instr_rvalid_i;
    logic [31:0] instr_rdata_i;
    logic instr_req_o;
    logic [31:0] instr_addr_o;
    logic instr_valid_id_o;
    logic [31:0] instr_rdata_id_o;
    logic is_compressed_id_o;
    logic illegal_c_insn_id_o;
    logic [31:0] pc_if_o;
    logic [31:0] pc_id_o;
    logic if_valid_o;
    logic if_busy_o;
    logic perf_imiss_o;

    constraint c_core
    {
        req_i dist {1 := 95, 0 := 5};
        pc_set_i dist {1 := 5, 0 := 95};
        pc_set_i -> req_i;
        !req_i -> halt_if_i;
        pc_mux_i dist {`PC_BOOT := 10, `PC_JUMP := 40, `PC_EXCEPTION := 25, `PC_ERET := 15, `PC_DBG_NPC := 10};
        exc_pc_mux_i dist {`EXC_PC_ILLINSN := 30, `EXC_PC_ECALL := 30, `EXC_PC_IRQ := 30, `EXC_PC_LOAD := 10};
        jump_target_ex_i[0] == 1'b0;
        halt_if_i dist {1 := 10, 0 := 90};
        id_ready_i dist {1 := 80, 0 := 20};
        clear_instr_valid_i dist {1 := 50, 0 := 50};
    }

    constraint c_mem
    {
        instr_gnt_i dist {1 := 70, 0 := 30};
        lat dist {0 := 60, 1 := 25, [2:3] :/ 15};
    }

    static function logic [31:0] mem_word(logic [31:0] addr);
        logic [31:0] h;
        logic [31:0] w;
        h = {addr[31:2], 2'b00} * 32'h9E37_79B1;
        h = h ^ (h >> 15) ^ 32'h5bd1_e995;
        w = h * 32'h85EB_CA6B;
        w = w ^ (w >> 13);
        if (h[3]) w[1:0]   = 2'b11;
        if (h[7]) w[17:16] = 2'b11;
        return w;
    endfunction

    function void legalize();
        if (pc_set_i)
            req_i = 1'b1;
        if (!req_i)
            halt_if_i = 1'b1;
        jump_target_ex_i[0] = 1'b0;
        lat = lat % 4;
    endfunction

    function void display(string tag="TX");
        $display("[%s] req=%b pcset=%b mux=%0d exc=%0d halt=%b rdy=%b clr=%b | ifv=%b pc_if=%h | idv=%b pc_id=%h instr=%h c=%b ill=%b | mreq=%b gnt=%b rv=%b",
                 tag, req_i, pc_set_i, pc_mux_i, exc_pc_mux_i, halt_if_i, id_ready_i, clear_instr_valid_i,
                 if_valid_o, pc_if_o, instr_valid_id_o, pc_id_o, instr_rdata_id_o, is_compressed_id_o, illegal_c_insn_id_o,
                 instr_req_o, instr_gnt_i, instr_rvalid_i);
    endfunction

    function If_Transaction do_copy();
        If_Transaction copy;
        copy = new();
        copy.req_i = this.req_i;
        copy.clear_instr_valid_i = this.clear_instr_valid_i;
        copy.pc_set_i = this.pc_set_i;
        copy.exception_pc_reg_i = this.exception_pc_reg_i;
        copy.pc_mux_i = this.pc_mux_i;
        copy.exc_pc_mux_i = this.exc_pc_mux_i;
        copy.exc_vec_pc_mux_i = this.exc_vec_pc_mux_i;
        copy.jump_target_ex_i = this.jump_target_ex_i;
        copy.dbg_jump_addr_i = this.dbg_jump_addr_i;
        copy.halt_if_i = this.halt_if_i;
        copy.id_ready_i = this.id_ready_i;
        copy.instr_gnt_i = this.instr_gnt_i;
        copy.lat = this.lat;
        copy.rst_n = this.rst_n;
        copy.boot_addr_i = this.boot_addr_i;
        copy.instr_rvalid_i = this.instr_rvalid_i;
        copy.instr_rdata_i = this.instr_rdata_i;
        copy.instr_req_o = this.instr_req_o;
        copy.instr_addr_o = this.instr_addr_o;
        copy.instr_valid_id_o = this.instr_valid_id_o;
        copy.instr_rdata_id_o = this.instr_rdata_id_o;
        copy.is_compressed_id_o = this.is_compressed_id_o;
        copy.illegal_c_insn_id_o = this.illegal_c_insn_id_o;
        copy.pc_if_o = this.pc_if_o;
        copy.pc_id_o = this.pc_id_o;
        copy.if_valid_o = this.if_valid_o;
        copy.if_busy_o = this.if_busy_o;
        copy.perf_imiss_o = this.perf_imiss_o;
        return copy;
    endfunction
endclass
