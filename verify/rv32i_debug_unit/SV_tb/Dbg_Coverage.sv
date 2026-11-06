class Dbg_Coverage;
    mailbox #(Dbg_Transaction) mon2cov;
    Dbg_Transaction tx;

    logic        req;
    logic        we;
    logic        gnt;
    logic [14:0] addr;
    logic        halted;
    logic        dreq;
    logic        trap;
    logic        rreq;
    logic        wreq;
    logic        csr_req;
    logic        csr_we;
    logic        jump;

    covergroup cg;
        option.per_instance = 1;

        cp_target : coverpoint {addr[14], addr[13:8]} iff (req && gnt) {
            bins dbg_regs = {7'h00};
            bins pcs      = {7'h20};
            bins gpr      = {7'h04};
            bins csr      = {[7'h40:7'h7F]};
        }

        cp_dbg_reg : coverpoint addr[6:2] iff (req && gnt && addr[14:8] == 7'h00) {
            bins ctrl  = {5'd0};
            bins hit   = {5'd1};
            bins ie    = {5'd2};
            bins cause = {5'd3};
            bins other = {[5'd4:5'd31]};
        }

        cp_dir : coverpoint we iff (req && gnt);

        cp_halted : coverpoint halted;

        cp_halt_seq : coverpoint {dreq, halted} {
            bins running  = {2'b00};
            bins requested = {2'b10};
            bins halted    = {2'b01};
        }

        cp_side : coverpoint {rreq, wreq, csr_req, csr_we, jump} {
            bins gpr_read  = {5'b10000};
            bins gpr_write = {5'b01000};
            bins csr_req   = {5'b00100};
            bins csr_write = {5'b00010, 5'b00110};
            bins jump      = {5'b00001};
        }

        cp_trap : coverpoint trap;

        x_target_dir_halted : cross cp_target, cp_dir, cp_halted;
    endgroup

    function new(mailbox #(Dbg_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            req     = tx.debug_req_i;
            we      = tx.debug_we_i;
            gnt     = tx.debug_gnt_o;
            addr    = tx.debug_addr_i;
            halted  = tx.debug_halted_o;
            dreq    = tx.dbg_req_o;
            trap    = tx.trap_i;
            rreq    = tx.regfile_rreq_o;
            wreq    = tx.regfile_wreq_o;
            csr_req = tx.csr_req_o;
            csr_we  = tx.csr_we_o;
            jump    = tx.jump_req_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
