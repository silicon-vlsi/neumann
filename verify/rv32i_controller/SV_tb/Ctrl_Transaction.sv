`include "rv32i_defines.vh"
class Ctrl_Transaction;
    rand logic fetch_enable_i;
    rand logic illegal_insn_i;
    rand logic ecall_insn_i;
    rand logic mret_insn_i;
    rand logic pipe_flush_i;
    rand logic ebrk_insn_i;
    rand logic csr_status_i;
    rand logic instr_valid_i;
    rand logic data_misaligned_i;
    rand logic branch_in_id_i;
    rand logic branch_taken_ex_i;
    rand logic branch_set_i;
    rand logic jump_set_i;
    rand logic instr_multicyle_i;
    rand logic irq_req_ctrl_i;
    rand logic m_IE_i;
    rand logic dbg_req_i;
    rand logic dbg_stall_i;
    rand logic dbg_jump_req_i;
    rand logic id_ready_i;
    rand logic [4:0] irq_id_ctrl_i;
    rand logic [`DBG_SETS_W-1:0] dbg_settings_i;

    logic rst_n;
    logic ctrl_busy_o;
    logic first_fetch_o;
    logic is_decoding_o;
    logic deassert_we_o;
    logic instr_req_o;
    logic pc_set_o;
    logic irq_ack_o;
    logic exc_ack_o;
    logic exc_kill_o;
    logic csr_save_if_o;
    logic csr_save_id_o;
    logic csr_restore_mret_id_o;
    logic csr_save_cause_o;
    logic dbg_ack_o;
    logic dbg_trap_o;
    logic halt_if_o;
    logic halt_id_o;
    logic perf_jump_o;
    logic perf_tbranch_o;
    logic [2:0] pc_mux_o;
    logic [1:0] exc_pc_mux_o;
    logic [4:0] irq_id_o;
    logic [5:0] exc_cause_o;
    logic [5:0] csr_cause_o;
    logic [1:0] operand_a_fw_mux_sel_o;
    logic [3:0] dbg_cs;

    constraint c_run
    {
        fetch_enable_i dist {1 := 95, 0 := 5};
        instr_valid_i dist {1 := 80, 0 := 20};
        id_ready_i dist {1 := 80, 0 := 20};
        data_misaligned_i dist {1 := 5, 0 := 95};
    }

    constraint c_instr
    {
        illegal_insn_i dist {1 := 3, 0 := 97};
        ecall_insn_i dist {1 := 3, 0 := 97};
        mret_insn_i dist {1 := 3, 0 := 97};
        pipe_flush_i dist {1 := 2, 0 := 98};
        ebrk_insn_i dist {1 := 2, 0 := 98};
        csr_status_i dist {1 := 3, 0 := 97};
        branch_in_id_i dist {1 := 15, 0 := 85};
        branch_taken_ex_i dist {1 := 10, 0 := 90};
        branch_set_i dist {1 := 8, 0 := 92};
        jump_set_i dist {1 := 8, 0 := 92};
        instr_multicyle_i dist {1 := 20, 0 := 80};
    }

    constraint c_irq_dbg
    {
        irq_req_ctrl_i dist {1 := 10, 0 := 90};
        m_IE_i dist {1 := 60, 0 := 40};
        dbg_req_i dist {1 := 4, 0 := 96};
        dbg_stall_i dist {1 := 60, 0 := 40};
        dbg_jump_req_i dist {1 := 10, 0 := 90};
    }

    function void display(string tag="TX");
        $display("[%s] cs=%0d fe=%b iv=%b rdy=%b ill=%b ecall=%b mret=%b wfi=%b ebrk=%b csrst=%b bset=%b jset=%b irq=%b ie=%b dreq=%b dstall=%b | pc_set=%b mux=%0d halt=%b%b busy=%b",
                 tag, dbg_cs, fetch_enable_i, instr_valid_i, id_ready_i, illegal_insn_i, ecall_insn_i, mret_insn_i,
                 pipe_flush_i, ebrk_insn_i, csr_status_i, branch_set_i, jump_set_i, irq_req_ctrl_i, m_IE_i,
                 dbg_req_i, dbg_stall_i, pc_set_o, pc_mux_o, halt_if_o, halt_id_o, ctrl_busy_o);
    endfunction

    function Ctrl_Transaction do_copy();
        Ctrl_Transaction copy;
        copy = new();
        copy.rst_n = this.rst_n;
        copy.fetch_enable_i = this.fetch_enable_i;
        copy.illegal_insn_i = this.illegal_insn_i;
        copy.ecall_insn_i = this.ecall_insn_i;
        copy.mret_insn_i = this.mret_insn_i;
        copy.pipe_flush_i = this.pipe_flush_i;
        copy.ebrk_insn_i = this.ebrk_insn_i;
        copy.csr_status_i = this.csr_status_i;
        copy.instr_valid_i = this.instr_valid_i;
        copy.data_misaligned_i = this.data_misaligned_i;
        copy.branch_in_id_i = this.branch_in_id_i;
        copy.branch_taken_ex_i = this.branch_taken_ex_i;
        copy.branch_set_i = this.branch_set_i;
        copy.jump_set_i = this.jump_set_i;
        copy.instr_multicyle_i = this.instr_multicyle_i;
        copy.irq_req_ctrl_i = this.irq_req_ctrl_i;
        copy.m_IE_i = this.m_IE_i;
        copy.dbg_req_i = this.dbg_req_i;
        copy.dbg_stall_i = this.dbg_stall_i;
        copy.dbg_jump_req_i = this.dbg_jump_req_i;
        copy.id_ready_i = this.id_ready_i;
        copy.irq_id_ctrl_i = this.irq_id_ctrl_i;
        copy.dbg_settings_i = this.dbg_settings_i;
        copy.ctrl_busy_o = this.ctrl_busy_o;
        copy.first_fetch_o = this.first_fetch_o;
        copy.is_decoding_o = this.is_decoding_o;
        copy.deassert_we_o = this.deassert_we_o;
        copy.instr_req_o = this.instr_req_o;
        copy.pc_set_o = this.pc_set_o;
        copy.irq_ack_o = this.irq_ack_o;
        copy.exc_ack_o = this.exc_ack_o;
        copy.exc_kill_o = this.exc_kill_o;
        copy.csr_save_if_o = this.csr_save_if_o;
        copy.csr_save_id_o = this.csr_save_id_o;
        copy.csr_restore_mret_id_o = this.csr_restore_mret_id_o;
        copy.csr_save_cause_o = this.csr_save_cause_o;
        copy.dbg_ack_o = this.dbg_ack_o;
        copy.dbg_trap_o = this.dbg_trap_o;
        copy.halt_if_o = this.halt_if_o;
        copy.halt_id_o = this.halt_id_o;
        copy.perf_jump_o = this.perf_jump_o;
        copy.perf_tbranch_o = this.perf_tbranch_o;
        copy.pc_mux_o = this.pc_mux_o;
        copy.exc_pc_mux_o = this.exc_pc_mux_o;
        copy.irq_id_o = this.irq_id_o;
        copy.exc_cause_o = this.exc_cause_o;
        copy.csr_cause_o = this.csr_cause_o;
        copy.operand_a_fw_mux_sel_o = this.operand_a_fw_mux_sel_o;
        copy.dbg_cs = this.dbg_cs;
        return copy;
    endfunction
endclass
