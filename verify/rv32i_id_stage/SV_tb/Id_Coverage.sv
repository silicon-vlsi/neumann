`include "rv32i_defines.vh"
class Id_Coverage;
    mailbox #(Id_Transaction) mon2cov;
    Id_Transaction tx;

    logic [6:0] opcode;
    logic       valid;
    logic       decoding;
    logic       ready;
    logic       wb;
    logic       ex_ready;
    logic       bd;
    logic       pc_set;
    logic       misaligned;
    logic       dbg_r;
    logic       dbg_w;
    logic       rs1_zero;
    logic       rd_zero;

    covergroup cg;
        option.per_instance = 1;

        cp_opcode : coverpoint opcode iff (valid && decoding) {
            bins lui    = {`OPCODE_LUI};
            bins auipc  = {`OPCODE_AUIPC};
            bins jal    = {`OPCODE_JAL};
            bins jalr   = {`OPCODE_JALR};
            bins branch = {`OPCODE_BRANCH};
            bins load   = {`OPCODE_LOAD};
            bins store  = {`OPCODE_STORE};
            bins opimm  = {`OPCODE_OPIMM};
            bins op     = {`OPCODE_OP};
            bins system = {`OPCODE_SYSTEM};
        }

        cp_wb : coverpoint wb {
            bins idle = {1'b0};
            bins wait_multi = {1'b1};
        }

        cp_stall : coverpoint {wb, ex_ready} iff (valid) {
            bins idle      = {2'b00, 2'b01};
            bins wait_ex   = {2'b10};
            bins wb_done   = {2'b11};
        }

        cp_branch : coverpoint bd iff (valid && decoding && opcode == `OPCODE_BRANCH && !wb) {
            bins taken     = {1'b1};
            bins not_taken = {1'b0};
        }

        cp_ready : coverpoint ready;
        cp_pc_set : coverpoint pc_set;
        cp_mis : coverpoint misaligned iff (valid);
        cp_dbg : coverpoint {dbg_r, dbg_w} {
            bins none  = {2'b00};
            bins read  = {2'b10};
            bins write = {2'b01};
            bins both  = {2'b11};
        }
        cp_rd_zero : coverpoint rd_zero iff (valid && decoding);

        cp_multicycle : coverpoint opcode iff (valid && wb) {
            bins load   = {`OPCODE_LOAD};
            bins store  = {`OPCODE_STORE};
            bins jal    = {`OPCODE_JAL};
            bins jalr   = {`OPCODE_JALR};
            bins branch = {`OPCODE_BRANCH};
        }
    endgroup

    function new(mailbox #(Id_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            opcode     = tx.instr_rdata_i[6:0];
            valid      = tx.instr_valid_i;
            decoding   = tx.is_decoding_o;
            ready      = tx.id_ready_o;
            wb         = tx.dbg_wb_cs;
            ex_ready   = tx.ex_ready_i;
            bd         = tx.branch_decision_i;
            pc_set     = tx.pc_set_o;
            misaligned = tx.data_misaligned_i;
            dbg_r      = tx.dbg_reg_rreq_i;
            dbg_w      = tx.dbg_reg_wreq_i;
            rs1_zero   = (tx.instr_rdata_i[19:15] == 5'd0);
            rd_zero    = (tx.instr_rdata_i[11:7] == 5'd0);
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
