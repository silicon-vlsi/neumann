`include "rv32i_defines.vh"
class If_Coverage;
    mailbox #(If_Transaction) mon2cov;
    If_Transaction tx;

    logic       pc_set;
    logic [2:0] pc_mux;
    logic [1:0] exc_mux;
    logic       if_valid;
    logic       halt;
    logic       id_ready;
    logic       compressed;
    logic       illegal;
    logic       unaligned;
    logic       mreq;
    logic       gnt;
    logic       rvalid;

    covergroup cg;
        option.per_instance = 1;

        cp_pc_mux : coverpoint pc_mux iff (pc_set) {
            bins boot = {`PC_BOOT};
            bins jump = {`PC_JUMP};
            bins exc  = {`PC_EXCEPTION};
            bins eret = {`PC_ERET};
            bins dbg  = {`PC_DBG_NPC};
        }

        cp_exc : coverpoint exc_mux iff (pc_set && pc_mux == `PC_EXCEPTION) {
            bins illinsn = {`EXC_PC_ILLINSN};
            bins ecall   = {`EXC_PC_ECALL};
            bins irq     = {`EXC_PC_IRQ};
            bins load    = {`EXC_PC_LOAD};
        }

        cp_flow : coverpoint {halt, id_ready} {
            bins run       = {2'b01};
            bins id_stall  = {2'b00};
            bins halted    = {2'b10, 2'b11};
        }

        cp_kind : coverpoint {unaligned, compressed} iff (if_valid) {
            bins aligned_32   = {2'b00};
            bins aligned_16   = {2'b01};
            bins unaligned_32 = {2'b10};
            bins unaligned_16 = {2'b11};
        }

        cp_illegal_c : coverpoint illegal iff (compressed);

        cp_mem : coverpoint {mreq, gnt, rvalid} {
            bins wait_gnt = {3'b100};
            bins granted  = {3'b110};
            bins b2b      = {3'b111};
            bins rvalid   = {3'b001, 3'b011};
        }

        x_mux_kind : cross cp_pc_mux, cp_flow;
    endgroup

    function new(mailbox #(If_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            pc_set     = tx.pc_set_i;
            pc_mux     = tx.pc_mux_i;
            exc_mux    = tx.exc_pc_mux_i;
            if_valid   = tx.if_valid_o;
            halt       = tx.halt_if_i;
            id_ready   = tx.id_ready_i;
            compressed = tx.is_compressed_id_o;
            illegal    = tx.illegal_c_insn_id_o;
            unaligned  = tx.pc_if_o[1];
            mreq       = tx.instr_req_o;
            gnt        = tx.instr_gnt_i;
            rvalid     = tx.instr_rvalid_i;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
