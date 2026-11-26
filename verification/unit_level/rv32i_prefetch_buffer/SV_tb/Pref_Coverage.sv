class Pref_Coverage;
    mailbox #(Pref_Transaction) mon2cov;
    Pref_Transaction tx;

    logic       req;
    logic       branch;
    logic       ready;
    logic       valid;
    logic       mreq;
    logic       gnt;
    logic       rvalid;
    logic       unaligned;
    logic       compressed;

    covergroup cg;
        option.per_instance = 1;

        cp_branch : coverpoint branch;

        cp_mem : coverpoint {mreq, gnt} {
            bins no_req    = {2'b00, 2'b01};
            bins wait_gnt  = {2'b10};
            bins granted   = {2'b11};
        }

        cp_rvalid : coverpoint rvalid;

        cp_out : coverpoint {valid, ready} iff (!branch) {
            bins empty     = {2'b00, 2'b01};
            bins stall     = {2'b10};
            bins handshake = {2'b11};
        }

        cp_kind : coverpoint {unaligned, compressed} iff (valid && ready && !branch) {
            bins aligned_32   = {2'b00};
            bins aligned_16   = {2'b01};
            bins unaligned_32 = {2'b10};
            bins unaligned_16 = {2'b11};
        }

        cp_branch_ctx : coverpoint {branch, mreq, rvalid} iff (branch) {
            bins idle         = {3'b100};
            bins with_rvalid  = {3'b101, 3'b111};
            bins while_req    = {3'b110};
        }

        x_req_gnt_rvalid : cross cp_mem, cp_rvalid;
    endgroup

    function new(mailbox #(Pref_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            req        = tx.req_i;
            branch     = tx.branch_i;
            ready      = tx.ready_i;
            valid      = tx.valid_o;
            mreq       = tx.instr_req_o;
            gnt        = tx.instr_gnt_i;
            rvalid     = tx.instr_rvalid_i;
            unaligned  = tx.addr_o[1];
            compressed = (tx.rdata_o[1:0] != 2'b11);
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
