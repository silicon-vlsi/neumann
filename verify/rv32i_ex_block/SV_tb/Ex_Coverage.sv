class Ex_Coverage;
    mailbox #(Ex_Transaction) mon2cov;
    Ex_Transaction tx;

    logic [`ALU_OP_WIDTH-1:0] op;
    logic [31:0] a;
    logic [31:0] b;
    logic lsu_en;
    logic lsu_ready;
    logic branch;
    logic ready;

    covergroup cg;
        option.per_instance = 1;

        cp_op : coverpoint op {
            bins add  = {`ALU_ADD};
            bins sub  = {`ALU_SUB};
            bins and_ = {`ALU_AND};
            bins or_  = {`ALU_OR};
            bins xor_ = {`ALU_XOR};
            bins sll  = {`ALU_SLL};
            bins srl  = {`ALU_SRL};
            bins sra  = {`ALU_SRA};
            bins eq   = {`ALU_EQ};
            bins ne   = {`ALU_NE};
            bins gtu  = {`ALU_GTU};
            bins geu  = {`ALU_GEU};
            bins ltu  = {`ALU_LTU};
            bins leu  = {`ALU_LEU};
            bins gts  = {`ALU_GTS};
            bins ges  = {`ALU_GES};
            bins lts  = {`ALU_LTS};
            bins les  = {`ALU_LES};
            bins slts = {`ALU_SLTS};
            bins sltu = {`ALU_SLTU};
            bins slets = {`ALU_SLETS};
            bins sletu = {`ALU_SLETU};
        }

        cp_a : coverpoint a {
            bins zero = {32'h0};
            bins ones = {32'hFFFF_FFFF};
            bins maxp = {32'h7FFF_FFFF};
            bins minn = {32'h8000_0000};
            bins pos  = {[32'h1:32'h7FFF_FFFE]};
            bins neg  = {[32'h8000_0001:32'hFFFF_FFFE]};
        }

        cp_b : coverpoint b {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFF_FFFF};
            bins maxp  = {32'h7FFF_FFFF};
            bins minn  = {32'h8000_0000};
            bins shamt = {[1:31]};
            bins other = default;
        }

        cp_branch : coverpoint branch iff (op inside {`ALU_EQ, `ALU_NE, `ALU_GTU, `ALU_GEU, `ALU_LTU, `ALU_LEU,
                                                     `ALU_GTS, `ALU_GES, `ALU_LTS, `ALU_LES}) {
            bins taken     = {1'b1};
            bins not_taken = {1'b0};
        }

        cp_lsu : coverpoint {lsu_en, lsu_ready} {
            bins no_lsu_0 = {2'b00};
            bins no_lsu_1 = {2'b01};
            bins stall    = {2'b10};
            bins done     = {2'b11};
        }

        x_op_branch : cross cp_op, cp_branch {
            ignore_bins non_cmp = binsof(cp_op) intersect {`ALU_ADD, `ALU_SUB, `ALU_AND, `ALU_OR, `ALU_XOR,
                                                            `ALU_SLL, `ALU_SRL, `ALU_SRA,
                                                            `ALU_SLTS, `ALU_SLTU, `ALU_SLETS, `ALU_SLETU};
        }
        x_op_a : cross cp_op, cp_a;
    endgroup

    function new(mailbox #(Ex_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            op        = tx.alu_operator_i;
            a         = tx.alu_operand_a_i;
            b         = tx.alu_operand_b_i;
            lsu_en    = tx.lsu_en_i;
            lsu_ready = tx.lsu_ready_ex_i;
            branch    = tx.branch_decision_o;
            ready     = tx.ex_ready_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
