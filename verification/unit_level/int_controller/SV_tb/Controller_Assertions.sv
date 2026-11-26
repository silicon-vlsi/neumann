module Controller_Assertions (
    input logic       clk,
    input logic       rst_n,
    input logic       ctrl_ack_i,
    input logic       ctrl_kill_i,
    input logic       irq_i,
    input logic [4:0] irq_id_i,
    input logic       m_IE_i,
    input logic       irq_req_ctrl_o,
    input logic [4:0] irq_id_ctrl_o,
    input logic [1:0] exc_ctrl_cs
);

    localparam IDLE        = 2'b00;
    localparam IRQ_PENDING = 2'b01;
    localparam IRQ_DONE    = 2'b10;

    wire irq_take = (exc_ctrl_cs == IDLE) && irq_i && m_IE_i;

    property p_reset;
        @(posedge clk)
        !rst_n |=> (exc_ctrl_cs == IDLE) && (irq_id_ctrl_o == 5'b0);
    endproperty
    a_reset : assert property (p_reset)
        else $error("INT_CTRL: state/id not cleared by reset");

    property p_state_legal;
        @(posedge clk) disable iff (!rst_n)
        exc_ctrl_cs inside {IDLE, IRQ_PENDING, IRQ_DONE};
    endproperty
    a_state_legal : assert property (p_state_legal)
        else $error("INT_CTRL: illegal FSM state %b", exc_ctrl_cs);

    property p_req_eq_pending;
        @(posedge clk) disable iff (!rst_n)
        irq_req_ctrl_o == (exc_ctrl_cs == IRQ_PENDING);
    endproperty
    a_req_eq_pending : assert property (p_req_eq_pending)
        else $error("INT_CTRL: irq_req_ctrl_o=%b in state %b", irq_req_ctrl_o, exc_ctrl_cs);

    property p_no_x_out;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown({irq_req_ctrl_o, irq_id_ctrl_o});
    endproperty
    a_no_x_out : assert property (p_no_x_out)
        else $error("INT_CTRL: X/Z on outputs");

    property p_idle_take;
        @(posedge clk) disable iff (!rst_n)
        irq_take |=> (exc_ctrl_cs == IRQ_PENDING) && (irq_id_ctrl_o == $past(irq_id_i));
    endproperty
    a_idle_take : assert property (p_idle_take)
        else $error("INT_CTRL: enabled irq not taken / wrong id captured");

    property p_idle_stay;
        @(posedge clk) disable iff (!rst_n)
        (exc_ctrl_cs == IDLE) && !(irq_i && m_IE_i) |=> (exc_ctrl_cs == IDLE);
    endproperty
    a_idle_stay : assert property (p_idle_stay)
        else $error("INT_CTRL: left IDLE without enabled irq");

    property p_id_stable;
        @(posedge clk) disable iff (!rst_n)
        !irq_take |=> $stable(irq_id_ctrl_o);
    endproperty
    a_id_stable : assert property (p_id_stable)
        else $error("INT_CTRL: irq_id_ctrl_o changed without a new irq");

    property p_pend_ack;
        @(posedge clk) disable iff (!rst_n)
        (exc_ctrl_cs == IRQ_PENDING) && ctrl_ack_i |=> (exc_ctrl_cs == IRQ_DONE);
    endproperty
    a_pend_ack : assert property (p_pend_ack)
        else $error("INT_CTRL: ack did not move PENDING -> DONE");

    property p_pend_kill;
        @(posedge clk) disable iff (!rst_n)
        (exc_ctrl_cs == IRQ_PENDING) && !ctrl_ack_i && ctrl_kill_i |=> (exc_ctrl_cs == IDLE);
    endproperty
    a_pend_kill : assert property (p_pend_kill)
        else $error("INT_CTRL: kill did not move PENDING -> IDLE");

    property p_pend_hold;
        @(posedge clk) disable iff (!rst_n)
        (exc_ctrl_cs == IRQ_PENDING) && !ctrl_ack_i && !ctrl_kill_i |=> (exc_ctrl_cs == IRQ_PENDING);
    endproperty
    a_pend_hold : assert property (p_pend_hold)
        else $error("INT_CTRL: request dropped without ack/kill");

    property p_done_idle;
        @(posedge clk) disable iff (!rst_n)
        (exc_ctrl_cs == IRQ_DONE) |=> (exc_ctrl_cs == IDLE);
    endproperty
    a_done_idle : assert property (p_done_idle)
        else $error("INT_CTRL: DONE did not return to IDLE");

    c_idle     : cover property (@(posedge clk) disable iff (!rst_n) exc_ctrl_cs == IDLE);
    c_pending  : cover property (@(posedge clk) disable iff (!rst_n) exc_ctrl_cs == IRQ_PENDING);
    c_done     : cover property (@(posedge clk) disable iff (!rst_n) exc_ctrl_cs == IRQ_DONE);
    c_ack_path : cover property (@(posedge clk) disable iff (!rst_n)
                     (exc_ctrl_cs == IDLE) ##1 (exc_ctrl_cs == IRQ_PENDING) ##1
                     (exc_ctrl_cs == IRQ_DONE) ##1 (exc_ctrl_cs == IDLE));
    c_kill     : cover property (@(posedge clk) disable iff (!rst_n)
                     (exc_ctrl_cs == IRQ_PENDING) && !ctrl_ack_i && ctrl_kill_i);
    c_ack_kill : cover property (@(posedge clk) disable iff (!rst_n)
                     (exc_ctrl_cs == IRQ_PENDING) && ctrl_ack_i && ctrl_kill_i);
    c_masked   : cover property (@(posedge clk) disable iff (!rst_n)
                     (exc_ctrl_cs == IDLE) && irq_i && !m_IE_i);
    c_long_pend: cover property (@(posedge clk) disable iff (!rst_n)
                     (exc_ctrl_cs == IRQ_PENDING) [*3]);

endmodule

bind rv32i_int_controller Controller_Assertions u_assert (
    .clk            (clk),
    .rst_n          (rst_n),
    .ctrl_ack_i     (ctrl_ack_i),
    .ctrl_kill_i    (ctrl_kill_i),
    .irq_i          (irq_i),
    .irq_id_i       (irq_id_i),
    .m_IE_i         (m_IE_i),
    .irq_req_ctrl_o (irq_req_ctrl_o),
    .irq_id_ctrl_o  (irq_id_ctrl_o),
    .exc_ctrl_cs    (exc_ctrl_cs)
);
