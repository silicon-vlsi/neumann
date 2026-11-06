`include "rv32i_defines.vh"
`include "Csr_tb_cfg.svh"
class Csr_Transaction;
    rand logic        csr_access_i;
    rand logic [11:0] csr_addr_i;
    rand logic [31:0] csr_wdata_i;
    rand logic [1:0]  csr_op_i;
    rand logic [31:0] pc_if_i;
    rand logic [31:0] pc_id_i;
    rand logic        csr_save_if_i;
    rand logic        csr_save_id_i;
    rand logic        csr_restore_mret_i;
    rand logic [5:0]  csr_cause_i;
    rand logic        csr_save_cause_i;
    rand logic        if_valid_i;
    rand logic        id_valid_i;
    rand logic        is_compressed_i;
    rand logic        is_decoding_i;
    rand logic        imiss_i;
    rand logic        pc_set_i;
    rand logic        jump_i;
    rand logic        branch_i;
    rand logic        branch_taken_i;
    rand logic        mem_load_i;
    rand logic        mem_store_i;

    logic        rst_n;
    logic [3:0]  core_id_i;
    logic [5:0]  cluster_id_i;
    logic [23:0] boot_addr_i;
    logic [31:0] csr_rdata_o;
    logic        m_irq_enable_o;
    logic [31:0] mepc_o;

    constraint c_access
    {
        csr_access_i dist {1 := 70, 0 := 30};
        csr_addr_i dist {
            12'h300 := 15, 12'h305 := 5, 12'h341 := 10, 12'h342 := 10, 12'hF14 := 5,
            12'h7A0 := 8, 12'h7A1 := 8, 12'h79F := 3, [`CSR_PCCR_FIRST:`CSR_PCCR_LAST] :/ 25,
            [`CSR_PCCR_UNIMPL_FIRST:`CSR_PCCR_UNIMPL_LAST] :/ 2, [12'h000:12'hFFF] :/ 9
        };
        csr_op_i dist {`CSR_OP_NONE := 40, `CSR_OP_WRITE := 20, `CSR_OP_SET := 20, `CSR_OP_CLEAR := 20};
        !csr_access_i -> (csr_op_i == `CSR_OP_NONE);
    }

    constraint c_exc
    {
        csr_save_cause_i dist {1 := 5, 0 := 95};
        csr_restore_mret_i dist {1 := 5, 0 := 95};
        csr_save_if_i dist {1 := 50, 0 := 50};
        csr_save_id_i == !csr_save_if_i;
    }

    constraint c_perf
    {
        if_valid_i dist {1 := 50, 0 := 50};
        id_valid_i dist {1 := 50, 0 := 50};
        imiss_i dist {1 := 20, 0 := 80};
        pc_set_i dist {1 := 10, 0 := 90};
    }

    function void legalize();
        if (!csr_access_i)
            csr_op_i = `CSR_OP_NONE;
    endfunction

    function void display(string tag="TX");
        $display("[%s] acc=%b addr=%h op=%0d wdata=%h | save=%b if=%b id=%b mret=%b cause=%h | rdata=%h mie=%b mepc=%h",
                 tag, csr_access_i, csr_addr_i, csr_op_i, csr_wdata_i, csr_save_cause_i, csr_save_if_i, csr_save_id_i,
                 csr_restore_mret_i, csr_cause_i, csr_rdata_o, m_irq_enable_o, mepc_o);
    endfunction

    function Csr_Transaction do_copy();
        Csr_Transaction copy;
        copy = new();
        copy.csr_access_i = this.csr_access_i;
        copy.csr_addr_i = this.csr_addr_i;
        copy.csr_wdata_i = this.csr_wdata_i;
        copy.csr_op_i = this.csr_op_i;
        copy.pc_if_i = this.pc_if_i;
        copy.pc_id_i = this.pc_id_i;
        copy.csr_save_if_i = this.csr_save_if_i;
        copy.csr_save_id_i = this.csr_save_id_i;
        copy.csr_restore_mret_i = this.csr_restore_mret_i;
        copy.csr_cause_i = this.csr_cause_i;
        copy.csr_save_cause_i = this.csr_save_cause_i;
        copy.if_valid_i = this.if_valid_i;
        copy.id_valid_i = this.id_valid_i;
        copy.is_compressed_i = this.is_compressed_i;
        copy.is_decoding_i = this.is_decoding_i;
        copy.imiss_i = this.imiss_i;
        copy.pc_set_i = this.pc_set_i;
        copy.jump_i = this.jump_i;
        copy.branch_i = this.branch_i;
        copy.branch_taken_i = this.branch_taken_i;
        copy.mem_load_i = this.mem_load_i;
        copy.mem_store_i = this.mem_store_i;
        copy.rst_n = this.rst_n;
        copy.core_id_i = this.core_id_i;
        copy.cluster_id_i = this.cluster_id_i;
        copy.boot_addr_i = this.boot_addr_i;
        copy.csr_rdata_o = this.csr_rdata_o;
        copy.m_irq_enable_o = this.m_irq_enable_o;
        copy.mepc_o = this.mepc_o;
        return copy;
    endfunction
endclass
