`include "rv32i_defines.vh"
class Dbg_Generator;
    mailbox #(Dbg_Transaction) gen2drv;
    int num_tx    = 100;
    int gen_count = 0;
    bit done      = 0;

    function new(mailbox #(Dbg_Transaction) gen2drv, int num_tx);
        this.gen2drv = gen2drv;
        this.num_tx  = num_tx;
    endfunction

    function Dbg_Transaction quiet(bit ack = 0);
        Dbg_Transaction tx;
        tx = new();
        tx.bus_start        = 0;
        tx.bus_addr         = 0;
        tx.bus_we           = 0;
        tx.bus_wdata        = 0;
        tx.debug_halt_i     = 0;
        tx.debug_resume_i   = 0;
        tx.trap_i           = 0;
        tx.exc_cause_i      = 0;
        tx.dbg_ack_i        = ack;
        tx.regfile_rdata_i  = $urandom();
        tx.csr_rdata_i      = $urandom();
        tx.pc_if_i          = $urandom();
        tx.pc_id_i          = $urandom();
        tx.instr_valid_id_i = 1;
        tx.sleeping_i       = 0;
        return tx;
    endfunction

    task put(Dbg_Transaction tx);
        gen2drv.put(tx.do_copy());
        gen_count++;
    endtask

    task bus(logic [14:0] addr, bit we, logic [31:0] wdata, bit ack = 0);
        Dbg_Transaction tx;
        tx = quiet(ack);
        tx.bus_start = 1;
        tx.bus_addr  = addr;
        tx.bus_we    = we;
        tx.bus_wdata = wdata;
        put(tx);
        tx = quiet(ack);
        put(tx);
        put(tx);
    endtask

    task wait_cycles(int n, bit ack = 0);
        repeat (n) put(quiet(ack));
    endtask

    task read_dbg_regs(bit ack);
        bus(15'h0000, 0, 0, ack);
        bus(15'h0004, 0, 0, ack);
        bus(15'h0008, 0, 0, ack);
        bus(15'h000C, 0, 0, ack);
        bus(15'h2000, 0, 0, ack);
        bus(15'h2004, 0, 0, ack);
    endtask

    task halt_via_ctrl(bit sste);
        bus(15'h0000, 1, {15'h0, 1'b1, 15'h0, sste});
        wait_cycles(2, 0);
        wait_cycles(3, 1);
    endtask

    task resume_via_ctrl(bit sste);
        bus(15'h0000, 1, {15'h0, 1'b0, 15'h0, sste}, 1);
        wait_cycles(2, 0);
    endtask

    task directed();
        Dbg_Transaction tx;
        wait_cycles(2);
        read_dbg_regs(0);
        bus(15'h0008, 1, 32'h0000_0FFF);
        bus(15'h0008, 0, 0);
        bus(15'h0008, 1, 32'h0000_0020);
        bus(15'h0008, 0, 0);
        bus(15'h0008, 1, 32'h0000_0000);
        bus(15'h0400, 0, 0);
        bus(15'h0404, 1, 32'hDEAD_BEEF);
        bus(15'h4004, 0, 0);
        bus(15'h4004, 1, 32'h1234_5678);
        bus(15'h2000, 1, 32'h0000_0100);
        halt_via_ctrl(0);
        read_dbg_regs(1);
        for (int r = 0; r < 32; r += 5) begin
            bus({8'h04, r[4:0], 2'b00}, 0, 0, 1);
            bus({8'h04, r[4:0], 2'b00}, 1, $urandom(), 1);
        end
        bus(15'h4000 + 15'h0C04, 0, 0, 1);
        bus(15'h4000 + 15'h0C04, 1, 32'hCAFE_0001, 1);
        bus(15'h4000 + 15'h1E00, 1, 32'h0000_0088, 1);
        bus(15'h2000, 1, 32'h0000_0400, 1);
        bus(15'h2004, 1, 32'h0000_0400, 1);
        resume_via_ctrl(1);
        tx = quiet();
        tx.trap_i      = 1;
        tx.exc_cause_i = 6'h0B;
        put(tx);
        wait_cycles(3, 1);
        bus(15'h000C, 0, 0, 1);
        bus(15'h0004, 0, 0, 1);
        bus(15'h0004, 1, 32'h1, 1);
        bus(15'h0004, 0, 0, 1);
        tx = quiet(1);
        tx.debug_resume_i = 1;
        put(tx);
        wait_cycles(2);
        tx = quiet();
        tx.debug_halt_i = 1;
        put(tx);
        wait_cycles(2);
        tx = quiet();
        tx.debug_resume_i = 1;
        put(tx);
        wait_cycles(2);
        tx = quiet();
        tx.debug_halt_i = 1;
        put(tx);
        wait_cycles(3, 1);
        tx = quiet(1);
        tx.sleeping_i = 1;
        put(tx);
        bus(15'h0004, 0, 0, 1);
        bus(15'h0000, 1, 32'h0, 1);
        wait_cycles(3);
    endtask

    task run();
        Dbg_Transaction tx;
        directed();
        $display("[GEN] directed done: %0d cycles", gen_count);
        repeat (num_tx) begin
            tx = new();
            if (!tx.randomize())
                $fatal(1, "[GEN] Randomization failed!!");
            tx.bus_addr[1:0] = 2'b00;
            put(tx);
        end
        done = 1;
    endtask
endclass
