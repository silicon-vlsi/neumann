class Ctrl_Coverage;
    mailbox #(Ctrl_Transaction) mon2cov;
    Ctrl_Transaction tx;

    logic [3:0] state;
    logic [2:0] pc_mux;
    logic       pc_set;
    logic [5:0] cause;
    logic       save;
    logic       dbg_ack;
    logic       irq_ack;
    logic       kill;
    logic       trap;

    covergroup cg;
        option.per_instance = 1;

        cp_state : coverpoint state {
            bins reset       = {4'd0};
            bins boot_set    = {4'd1};
            bins wait_sleep  = {4'd2};
            bins sleep       = {4'd3};
            bins first_fetch = {4'd4};
            bins decode      = {4'd5};
            bins flush       = {4'd6};
            bins irq_taken   = {4'd7};
            bins dbg_signal  = {4'd8};
            bins dbg_sig_slp = {4'd9};
            bins dbg_wait    = {4'd10};
            bins dbg_wait_sl = {4'd12};
        }

        cp_trans : coverpoint state {
            bins boot       = (4'd0 => 4'd1 => 4'd4 => 4'd5);
            bins to_flush   = (4'd5 => 4'd6);
            bins to_irq     = (4'd5 => 4'd7 => 4'd5);
            bins to_sleep   = (4'd6 => 4'd2 => 4'd3);
            bins wake       = (4'd3 => 4'd4);
            bins dbg        = (4'd5 => 4'd8 => 4'd10);
            bins dbg_back   = (4'd10 => 4'd5);
            bins dbg_sleep  = (4'd9 => 4'd12 => 4'd3);
            bins flush_dbg  = (4'd6 => 4'd8);
        }

        cp_pc_mux : coverpoint pc_mux iff (pc_set) {
            bins boot  = {3'b000};
            bins jump  = {3'b010};
            bins exc   = {3'b100};
            bins eret  = {3'b101};
            bins dbg   = {3'b111};
        }

        cp_cause : coverpoint cause iff (save) {
            bins illegal = {6'h02};
            bins ecall   = {6'h0B};
            bins irq     = {[6'h20:6'h3F]};
        }

        cp_kill : coverpoint kill;
        cp_trap : coverpoint trap;
        cp_irq_ack : coverpoint irq_ack;
        cp_dbg_ack : coverpoint dbg_ack;
    endgroup

    function new(mailbox #(Ctrl_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            state   = tx.dbg_cs;
            pc_mux  = tx.pc_mux_o;
            pc_set  = tx.pc_set_o;
            cause   = tx.csr_cause_o;
            save    = tx.csr_save_cause_o;
            dbg_ack = tx.dbg_ack_o;
            irq_ack = tx.irq_ack_o;
            kill    = tx.exc_kill_o;
            trap    = tx.dbg_trap_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
