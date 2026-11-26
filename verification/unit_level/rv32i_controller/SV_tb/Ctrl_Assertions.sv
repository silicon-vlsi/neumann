`include "rv32i_defines.vh"
module Ctrl_Assertions (
    input logic       clk,
    input logic       rst_n,
    input logic [3:0] cs,
    input logic       fetch_enable_i,
    input logic       pc_set_o,
    input logic [2:0] pc_mux_o,
    input logic       instr_req_o,
    input logic       ctrl_busy_o,
    input logic       irq_ack_o,
    input logic       exc_ack_o,
    input logic       csr_save_cause_o,
    input logic       csr_save_if_o,
    input logic       csr_save_id_o,
    input logic       csr_restore_mret_id_o,
    input logic       dbg_ack_o,
    input logic       is_decoding_o,
    input logic       deassert_we_o,
    input logic       illegal_insn_i,
    input logic       halt_if_o,
    input logic       halt_id_o
);

    localparam [3:0] RESET = 4'd0, BOOT_SET = 4'd1, SLEEP = 4'd3, DECODE = 4'd5,
                     FLUSH = 4'd6, IRQ_TAKEN = 4'd7, DBG_SIGNAL = 4'd8, DBG_SIGNAL_SLEEP = 4'd9;

    property p_legal_state;
        @(posedge clk) disable iff (rst_n !== 1'b1) cs <= 4'd12;
    endproperty
    a_legal_state : assert property (p_legal_state)
        else $error("CTRL: illegal FSM state %0d", cs);

    property p_reset_state;
        @(posedge clk) !rst_n |=> (cs == RESET);
    endproperty
    a_reset_state : assert property (p_reset_state)
        else $error("CTRL: not in RESET after reset");

    property p_boot;
        @(posedge clk) disable iff (rst_n !== 1'b1) (cs == BOOT_SET) |-> pc_set_o && (pc_mux_o == `PC_BOOT);
    endproperty
    a_boot : assert property (p_boot)
        else $error("CTRL: BOOT_SET without pc_set to boot address");

    property p_irq_ack;
        @(posedge clk) disable iff (rst_n !== 1'b1) irq_ack_o |-> exc_ack_o && csr_save_cause_o && csr_save_if_o && (pc_mux_o == `PC_EXCEPTION);
    endproperty
    a_irq_ack : assert property (p_irq_ack)
        else $error("CTRL: irq_ack without full exception entry");

    property p_irq_to_decode;
        @(posedge clk) disable iff (rst_n !== 1'b1) (cs == IRQ_TAKEN) |=> (cs == DECODE);
    endproperty
    a_irq_to_decode : assert property (p_irq_to_decode)
        else $error("CTRL: IRQ_TAKEN did not return to DECODE");

    property p_save_onehot;
        @(posedge clk) disable iff (rst_n !== 1'b1) csr_save_cause_o |-> (csr_save_if_o ^ csr_save_id_o);
    endproperty
    a_save_onehot : assert property (p_save_onehot)
        else $error("CTRL: save_cause without exactly one of save_if/save_id");

    property p_mret_eret;
        @(posedge clk) disable iff (rst_n !== 1'b1) csr_restore_mret_id_o |-> pc_set_o && (pc_mux_o == `PC_ERET) && (cs == FLUSH);
    endproperty
    a_mret_eret : assert property (p_mret_eret)
        else $error("CTRL: mret restore without ERET jump");

    property p_dbg_ack;
        @(posedge clk) disable iff (rst_n !== 1'b1) dbg_ack_o |-> (cs == DBG_SIGNAL || cs == DBG_SIGNAL_SLEEP) && halt_if_o;
    endproperty
    a_dbg_ack : assert property (p_dbg_ack)
        else $error("CTRL: dbg_ack outside DBG_SIGNAL");

    property p_sleep_quiet;
        @(posedge clk) disable iff (rst_n !== 1'b1) (cs == SLEEP) |-> !instr_req_o && !ctrl_busy_o && halt_if_o && halt_id_o;
    endproperty
    a_sleep_quiet : assert property (p_sleep_quiet)
        else $error("CTRL: core not quiet in SLEEP");

    property p_deassert_we;
        @(posedge clk) disable iff (rst_n !== 1'b1) (!is_decoding_o || illegal_insn_i) |-> deassert_we_o;
    endproperty
    a_deassert_we : assert property (p_deassert_we)
        else $error("CTRL: write enable not deasserted");

    c_sleep     : cover property (@(posedge clk) cs == SLEEP);
    c_dbg_sleep : cover property (@(posedge clk) cs == DBG_SIGNAL_SLEEP);
    c_irq       : cover property (@(posedge clk) irq_ack_o);
    c_boot      : cover property (@(posedge clk) (cs == RESET) ##1 (cs == BOOT_SET) ##1 (cs == 4'd4));

endmodule

bind rv32i_controller Ctrl_Assertions u_assert (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .cs                    (ctrl_fsm_cs),
    .fetch_enable_i        (fetch_enable_i),
    .pc_set_o              (pc_set_o),
    .pc_mux_o              (pc_mux_o),
    .instr_req_o           (instr_req_o),
    .ctrl_busy_o           (ctrl_busy_o),
    .irq_ack_o             (irq_ack_o),
    .exc_ack_o             (exc_ack_o),
    .csr_save_cause_o      (csr_save_cause_o),
    .csr_save_if_o         (csr_save_if_o),
    .csr_save_id_o         (csr_save_id_o),
    .csr_restore_mret_id_o (csr_restore_mret_id_o),
    .dbg_ack_o             (dbg_ack_o),
    .is_decoding_o         (is_decoding_o),
    .deassert_we_o         (deassert_we_o),
    .illegal_insn_i        (illegal_insn_i),
    .halt_if_o             (halt_if_o),
    .halt_id_o             (halt_id_o)
);
