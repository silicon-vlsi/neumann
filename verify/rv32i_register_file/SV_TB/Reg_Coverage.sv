class Reg_Coverage #(parameter RV32E = 0, parameter DATA_WIDTH = 32);
    typedef Reg_Transaction #(RV32E, DATA_WIDTH) tx_t;
    mailbox #(tx_t) mon2cov;
    tx_t tx;

    logic       we;
    logic       test_en;
    logic [4:0] waddr;
    logic [4:0] raddr_a;
    logic [4:0] raddr_b;
    logic [DATA_WIDTH-1:0] wdata;
    logic [4:0] last_waddr;
    logic       last_we;
    logic       raw_a;

    covergroup cg;
        option.per_instance = 1;

        cp_we : coverpoint we;

        cp_test_en : coverpoint test_en;

        cp_waddr : coverpoint waddr iff (we) {
            bins x0     = {0};
            bins reg_[] = {[1:31]};
        }

        cp_raddr_a : coverpoint raddr_a {
            bins x0     = {0};
            bins reg_[] = {[1:31]};
        }

        cp_raddr_b : coverpoint raddr_b {
            bins x0     = {0};
            bins reg_[] = {[1:31]};
        }

        cp_wdata : coverpoint wdata iff (we) {
            bins zero = {0};
            bins ones = {{DATA_WIDTH{1'b1}}};
            bins alt5 = {{(DATA_WIDTH/2){2'b01}}};
            bins altA = {{(DATA_WIDTH/2){2'b10}}};
            bins other = {[1:{DATA_WIDTH{1'b1}}-1]};
        }

        cp_raw : coverpoint raw_a {
            bins read_after_write = {1'b1};
        }

        cp_same_port : coverpoint (raddr_a == raddr_b) {
            bins same = {1'b1};
            bins diff = {1'b0};
        }

        x_we_ten : cross cp_we, cp_test_en;
        x_waddr_wdata : cross cp_waddr, cp_wdata;
    endgroup

    function new(mailbox #(tx_t) mon2cov);
        this.mon2cov = mon2cov;
        last_we = 0;
        last_waddr = 0;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            we      = tx.we_a_i;
            test_en = tx.test_en_i;
            waddr   = tx.waddr_a_i;
            raddr_a = tx.raddr_a_i;
            raddr_b = tx.raddr_b_i;
            wdata   = tx.wdata_a_i;
            raw_a   = last_we && (raddr_a == last_waddr);
            cg.sample();
            last_we    = we;
            last_waddr = waddr;
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
