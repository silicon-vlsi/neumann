`include "rv32i_defines.vh"
`include "Csr_tb_cfg.svh"
class Csr_Coverage;
    mailbox #(Csr_Transaction) mon2cov;
    Csr_Transaction tx;

    logic        access;
    logic [11:0] addr;
    logic [1:0]  op;
    logic        save;
    logic        save_if;
    logic        mret;
    logic        mie;
    logic [31:0] rdata;

    covergroup cg;
        option.per_instance = 1;

        cp_addr : coverpoint addr iff (access) {
            bins mstatus  = {12'h300};
            bins mtvec    = {12'h305};
            bins mepc     = {12'h341};
            bins mcause   = {12'h342};
            bins mhartid  = {12'hF14};
            bins pcer     = {12'h7A0};
            bins pcmr     = {12'h7A1};
            bins pccr_all = {12'h79F};
            bins pccr[]   = {[`CSR_PCCR_FIRST:`CSR_PCCR_LAST]};
            bins pccr_unimpl = {[`CSR_PCCR_UNIMPL_FIRST:`CSR_PCCR_UNIMPL_LAST]};
        }

        cp_op : coverpoint op iff (access) {
            bins none  = {`CSR_OP_NONE};
            bins write = {`CSR_OP_WRITE};
            bins set   = {`CSR_OP_SET};
            bins clear = {`CSR_OP_CLEAR};
        }

        cp_exc : coverpoint {save, save_if, mret} {
            bins save_id    = {3'b100, 3'b101};
            bins save_if    = {3'b110, 3'b111};
            bins mret       = {3'b001};
            bins none       = {3'b000};
        }

        cp_mie : coverpoint mie {
            bins off = {1'b0};
            bins on  = {1'b1};
        }

        cp_sat : coverpoint rdata iff (access && addr inside {[`CSR_PCCR_FIRST:`CSR_PCCR_LAST]}) {
            bins saturated = {32'hFFFF_FFFF};
            bins wrapped   = {[32'h0:32'h10]};
            bins counting  = {[32'h11:32'hFFFF_FFFE]};
        }

        x_addr_op : cross cp_addr, cp_op;
        x_exc_mie : cross cp_exc, cp_mie;
    endgroup

    function new(mailbox #(Csr_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            access  = tx.csr_access_i;
            addr    = tx.csr_addr_i;
            op      = tx.csr_op_i;
            save    = tx.csr_save_cause_i;
            save_if = tx.csr_save_if_i;
            mret    = tx.csr_restore_mret_i;
            mie     = tx.m_irq_enable_o;
            rdata   = tx.csr_rdata_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
