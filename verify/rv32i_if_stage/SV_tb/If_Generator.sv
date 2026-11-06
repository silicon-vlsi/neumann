`include "rv32i_defines.vh"
class If_Generator;
    mailbox #(If_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    function new(mailbox #(If_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    function If_Transaction run_tx();
        If_Transaction tx;
        tx = new();
        tx.req_i               = 1;
        tx.pc_set_i            = 0;
        tx.pc_mux_i            = `PC_JUMP;
        tx.exc_pc_mux_i        = `EXC_PC_IRQ;
        tx.exc_vec_pc_mux_i    = $urandom();
        tx.exception_pc_reg_i  = {$urandom_range(0, 32'h7FFF_FFFF), 1'b0};
        tx.jump_target_ex_i    = {$urandom_range(0, 32'h7FFF_FFFF), 1'b0};
        tx.dbg_jump_addr_i     = {$urandom_range(0, 32'h7FFF_FFFF), 1'b0};
        tx.halt_if_i           = 0;
        tx.id_ready_i          = 1;
        tx.clear_instr_valid_i = 1;
        tx.instr_gnt_i         = 1;
        tx.lat                 = 0;
        return tx;
    endfunction

    task put(If_Transaction tx);
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task stream(int n, bit slow);
        If_Transaction tx;
        repeat (n) begin
            tx = run_tx();
            if (slow) begin
                tx.instr_gnt_i         = $urandom_range(0, 1);
                tx.lat                 = $urandom_range(0, 3);
                tx.id_ready_i          = ($urandom_range(0, 3) != 0);
                tx.halt_if_i           = ($urandom_range(0, 7) == 0);
                tx.clear_instr_valid_i = $urandom_range(0, 1);
            end
            put(tx);
        end
    endtask

    task set_pc(logic [2:0] mux, logic [1:0] exc, bit unaligned);
        If_Transaction tx;
        tx = run_tx();
        tx.pc_set_i     = 1;
        tx.pc_mux_i     = mux;
        tx.exc_pc_mux_i = exc;
        if (unaligned) begin
            tx.jump_target_ex_i[1]   = 1'b1;
            tx.exception_pc_reg_i[1] = 1'b1;
            tx.dbg_jump_addr_i[1]    = 1'b1;
        end
        put(tx);
    endtask

    task directed();
        If_Transaction tx;
        logic [2:0] muxes[$];
        muxes = '{`PC_BOOT, `PC_JUMP, `PC_EXCEPTION, `PC_ERET, `PC_DBG_NPC};
        tx = run_tx();
        tx.req_i = 0;
        repeat (3) put(tx);
        set_pc(`PC_BOOT, `EXC_PC_IRQ, 0);
        stream(40, 0);
        set_pc(`PC_JUMP, `EXC_PC_IRQ, 1);
        stream(30, 0);
        set_pc(`PC_EXCEPTION, `EXC_PC_ILLINSN, 0);
        stream(20, 1);
        set_pc(`PC_EXCEPTION, `EXC_PC_ECALL, 0);
        stream(20, 1);
        for (int v = 0; v < 32; v += 7) begin
            tx = run_tx();
            tx.pc_set_i         = 1;
            tx.pc_mux_i         = `PC_EXCEPTION;
            tx.exc_pc_mux_i     = `EXC_PC_IRQ;
            tx.exc_vec_pc_mux_i = v;
            put(tx);
            stream(12, 0);
        end
        set_pc(`PC_EXCEPTION, `EXC_PC_LOAD, 0);
        stream(10, 0);
        set_pc(`PC_ERET, `EXC_PC_IRQ, 0);
        stream(20, 1);
        set_pc(`PC_ERET, `EXC_PC_IRQ, 1);
        stream(20, 0);
        set_pc(`PC_DBG_NPC, `EXC_PC_IRQ, 0);
        stream(20, 1);
        set_pc(`PC_DBG_NPC, `EXC_PC_IRQ, 1);
        stream(20, 0);
        for (int k = 0; k < 20; k++) begin
            set_pc(`PC_JUMP, `EXC_PC_IRQ, k[0]);
            stream($urandom_range(0, 4), 1);
        end
        foreach (muxes[m])
            for (int f = 0; f < 3; f++) begin
                tx = run_tx();
                tx.pc_set_i     = 1;
                tx.pc_mux_i     = muxes[m];
                tx.exc_pc_mux_i = $urandom_range(0, 3);
                tx.halt_if_i    = (f == 2);
                tx.id_ready_i   = (f != 1);
                put(tx);
                stream(6, 0);
            end
        for (int e = 0; e < 4; e++) begin
            tx = run_tx();
            tx.pc_set_i     = 1;
            tx.pc_mux_i     = `PC_EXCEPTION;
            tx.exc_pc_mux_i = e;
            put(tx);
            stream(6, 0);
        end
        tx = run_tx(); tx.halt_if_i = 1; repeat (6) put(tx);
        tx = run_tx(); tx.id_ready_i = 0; tx.clear_instr_valid_i = 0; repeat (6) put(tx);
        stream(40, 1);
    endtask

    task run();
        If_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d cycles", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.legalize();
            put(tx);
        end
        done = 1;
    endtask
endclass
