`include "rv32i_defines.vh"
module Csr_Assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        csr_access_i,
    input logic [11:0] csr_addr_i,
    input logic [1:0]  csr_op_i,
    input logic [31:0] csr_rdata_o,
    input logic        m_irq_enable_o,
    input logic [31:0] mepc_o,
    input logic [31:0] pc_if_i,
    input logic [31:0] pc_id_i,
    input logic        csr_save_if_i,
    input logic        csr_save_id_i,
    input logic        csr_restore_mret_i,
    input logic [5:0]  csr_cause_i,
    input logic        csr_save_cause_i,
    input logic        mstatus_mpie_q,
    input logic [5:0]  mcause_q,
    input logic [1:0]  PCMR_q
);

    property p_save_mie;
        @(posedge clk) disable iff (rst_n !== 1'b1) csr_save_cause_i |=> !m_irq_enable_o;
    endproperty
    a_save_mie : assert property (p_save_mie)
        else $error("CSR: mie not cleared on exception entry");

    property p_save_mpie;
        @(posedge clk) disable iff (rst_n !== 1'b1) csr_save_cause_i |=> (mstatus_mpie_q == $past(m_irq_enable_o));
    endproperty
    a_save_mpie : assert property (p_save_mpie)
        else $error("CSR: mpie does not hold the old mie");

    property p_save_cause;
        @(posedge clk) disable iff (rst_n !== 1'b1) csr_save_cause_i |=> (mcause_q == $past(csr_cause_i));
    endproperty
    a_save_cause : assert property (p_save_cause)
        else $error("CSR: mcause not captured");

    property p_save_if_pc;
        @(posedge clk) disable iff (rst_n !== 1'b1) (csr_save_cause_i && csr_save_if_i) |=> (mepc_o == $past(pc_if_i));
    endproperty
    a_save_if_pc : assert property (p_save_if_pc)
        else $error("CSR: mepc != pc_if after save_if");

    property p_save_id_pc;
        @(posedge clk) disable iff (rst_n !== 1'b1) (csr_save_cause_i && !csr_save_if_i && csr_save_id_i) |=> (mepc_o == $past(pc_id_i));
    endproperty
    a_save_id_pc : assert property (p_save_id_pc)
        else $error("CSR: mepc != pc_id after save_id");

    property p_mret;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (csr_restore_mret_i && !csr_save_cause_i) |=> (m_irq_enable_o == $past(mstatus_mpie_q)) && mstatus_mpie_q;
    endproperty
    a_mret : assert property (p_mret)
        else $error("CSR: mret did not restore mie / set mpie");

    property p_mtvec_ro;
        @(posedge clk) disable iff (rst_n !== 1'b1) (csr_addr_i == 12'h305) |-> (csr_rdata_o[7:0] == 8'h00);
    endproperty
    a_mtvec_ro : assert property (p_mtvec_ro)
        else $error("CSR: mtvec low byte not zero");

    property p_no_x_read;
        @(posedge clk) disable iff (rst_n !== 1'b1) csr_access_i |-> !$isunknown(csr_rdata_o);
    endproperty
    a_no_x_read : assert property (p_no_x_read)
        else $error("CSR: X on csr_rdata_o for address %h", csr_addr_i);

    property p_mstatus_mpp;
        @(posedge clk) disable iff (rst_n !== 1'b1) (csr_addr_i == 12'h300) |-> (csr_rdata_o[12:11] == 2'b11);
    endproperty
    a_mstatus_mpp : assert property (p_mstatus_mpp)
        else $error("CSR: mstatus.MPP is not M-mode");

    c_save   : cover property (@(posedge clk) csr_save_cause_i);
    c_mret   : cover property (@(posedge clk) csr_restore_mret_i);
    c_sat    : cover property (@(posedge clk) PCMR_q == 2'b11 && csr_access_i && csr_rdata_o == 32'hFFFF_FFFF);
    c_csrrc  : cover property (@(posedge clk) csr_access_i && csr_op_i == `CSR_OP_CLEAR);

endmodule

bind rv32i_cs_registers Csr_Assertions u_assert (
    .clk                (clk),
    .rst_n              (rst_n),
    .csr_access_i       (csr_access_i),
    .csr_addr_i         (csr_addr_i),
    .csr_op_i           (csr_op_i),
    .csr_rdata_o        (csr_rdata_o),
    .m_irq_enable_o     (m_irq_enable_o),
    .mepc_o             (mepc_o),
    .pc_if_i            (pc_if_i),
    .pc_id_i            (pc_id_i),
    .csr_save_if_i      (csr_save_if_i),
    .csr_save_id_i      (csr_save_id_i),
    .csr_restore_mret_i (csr_restore_mret_i),
    .csr_cause_i        (csr_cause_i),
    .csr_save_cause_i   (csr_save_cause_i),
    .mstatus_mpie_q     (mstatus_mpie_q),
    .mcause_q           (mcause_q),
    .PCMR_q             (PCMR_q)
);
