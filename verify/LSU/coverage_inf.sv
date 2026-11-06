class coverage_inf;

    mailbox #(transaction) mon2cov;
    virtual lsu_if vif;

    bit [1:0] s_type;
    bit [1:0] s_off;
    bit       s_we, s_sext, s_mis;
    bit [3:0] s_be;

    covergroup cg_txn;
        option.per_instance = 1;
        cp_type : coverpoint s_type {
            bins word={2'b00}; bins half={2'b01};
            bins byte0={2'b10}; bins byte1={2'b11};
        }
        cp_off  : coverpoint s_off {
            bins o0={2'b00}; bins o1={2'b01}; bins o2={2'b10}; bins o3={2'b11};
        }
        cp_we   : coverpoint s_we   { bins ld={0}; bins st={1}; }
        cp_sext : coverpoint s_sext { bins uns={0}; bins sgn={1}; }
        cp_mis  : coverpoint s_mis  { bins align={0}; bins mis={1}; }
        cp_be   : coverpoint s_be   { bins vals[] = {[4'b0001:4'b1111]}; }

        x_type_off  : cross cp_type, cp_off;
        x_type_we   : cross cp_type, cp_we;
        x_type_sext : cross cp_type, cp_sext;
    endgroup

    covergroup cg_fsm @(posedge vif.clk);
        option.per_instance = 1;
        cp_state : coverpoint vif.dbg_cs {
            bins IDLE            = {3'b000};
            bins WAIT_GNT_MIS    = {3'b001};
            bins WAIT_RVALID_MIS = {3'b010};
            bins WAIT_GNT        = {3'b011};
            bins WAIT_RVALID     = {3'b100};
            bins t_idle_wr  = (3'b000 => 3'b100);
            bins t_idle_wg  = (3'b000 => 3'b011);
            bins t_idle_mis = (3'b000 => 3'b010, 3'b001);
            bins t_wr_idle  = (3'b100 => 3'b000);
        }
    endgroup

    function new(mailbox #(transaction) mon2cov, virtual lsu_if vif);
        this.mon2cov = mon2cov;
        this.vif     = vif;
        cg_txn = new();
        cg_fsm = new();
    endfunction

    task run();
        transaction tr;
        forever begin
            mon2cov.get(tr);
            s_type = tr.dtype;
            s_off  = tr.addr[1:0];
            s_we   = tr.we;
            s_sext = tr.sext;
            s_mis  = tr.misaligned;
            s_be   = tr.be;
            cg_txn.sample();
        end
    endtask

    function void report();
        $display("========== COVERAGE ==========");
        $display(" Functional cov = %0.2f %%", cg_txn.get_coverage());
        $display(" FSM cov        = %0.2f %%", cg_fsm.get_coverage());
        $display("==============================");
    endfunction

endclass
