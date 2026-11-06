class Cdec_Coverage;
    mailbox #(Cdec_Transaction) mon2cov;
    Cdec_Transaction tx;

    logic [1:0] quadrant;
    logic [2:0] funct3;
    logic [4:0] rd;
    logic [4:0] rs2;
    logic       bit12;
    logic       is_comp;
    logic       illegal;

    covergroup cg;
        option.per_instance = 1;

        cp_quadrant : coverpoint quadrant {
            bins q0   = {2'b00};
            bins q1   = {2'b01};
            bins q2   = {2'b10};
            bins full = {2'b11};
        }

        cp_funct3 : coverpoint funct3;

        cp_rd : coverpoint rd {
            bins zero  = {5'd0};
            bins sp    = {5'd2};
            bins other = {5'd1, [5'd3:5'd31]};
        }

        cp_rs2 : coverpoint rs2 {
            bins zero    = {5'd0};
            bins nonzero = {[5'd1:5'd31]};
        }

        cp_illegal : coverpoint illegal {
            bins legal   = {1'b0};
            bins illegal = {1'b1};
        }

        x_q_f3 : cross cp_quadrant, cp_funct3 {
            ignore_bins full_q = binsof(cp_quadrant.full);
        }

        x_q2_f3_rd_rs2 : cross cp_quadrant, cp_funct3, cp_rd, cp_rs2 {
            ignore_bins not_q2 = binsof(cp_quadrant) intersect {2'b00, 2'b01, 2'b11};
        }
    endgroup

    function new(mailbox #(Cdec_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            quadrant = tx.instr_i[1:0];
            funct3   = tx.instr_i[15:13];
            rd       = tx.instr_i[11:7];
            rs2      = tx.instr_i[6:2];
            bit12    = tx.instr_i[12];
            is_comp  = tx.is_compressed_o;
            illegal  = tx.illegal_instr_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
