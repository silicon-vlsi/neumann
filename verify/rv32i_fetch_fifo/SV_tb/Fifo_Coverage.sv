class Fifo_Coverage;
    mailbox #(Fifo_Transaction) mon2cov;
    Fifo_Transaction tx;

    logic clear;
    logic in_valid;
    logic in_ready;
    logic out_valid;
    logic out_ready;
    logic unaligned;
    logic compressed;
    logic stored;

    covergroup cg;
        option.per_instance = 1;

        cp_clear : coverpoint clear;

        cp_in : coverpoint {in_valid, in_ready} {
            bins idle      = {2'b00};
            bins ready     = {2'b01};
            bins late_push = {2'b10};
            bins push      = {2'b11};
        }

        cp_out : coverpoint {out_valid, out_ready} iff (!clear) {
            bins empty    = {2'b00, 2'b01};
            bins stall    = {2'b10};
            bins handshake = {2'b11};
        }

        cp_kind : coverpoint {unaligned, compressed} iff (out_valid && out_ready && !clear) {
            bins aligned_32   = {2'b00};
            bins aligned_16   = {2'b01};
            bins unaligned_32 = {2'b10};
            bins unaligned_16 = {2'b11};
        }

        cp_stored : coverpoint stored iff (out_valid && out_ready && !clear) {
            bins bypass = {1'b0};
            bins stored = {1'b1};
        }

        cp_ready_trans : coverpoint in_ready {
            bins fill  = (1 => 0);
            bins drain = (0 => 1);
        }

        x_kind_stored : cross cp_kind, cp_stored {
            ignore_bins unaligned_16_bypass = binsof(cp_kind.unaligned_16) && binsof(cp_stored.bypass);
        }
    endgroup

    function new(mailbox #(Fifo_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            clear      = tx.clear_i;
            in_valid   = tx.in_valid_i;
            in_ready   = tx.in_ready_o;
            out_valid  = tx.out_valid_o;
            out_ready  = tx.out_ready_i;
            unaligned  = tx.out_addr_o[1];
            compressed = (tx.out_rdata_o[1:0] != 2'b11);
            stored     = tx.out_valid_stored_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
