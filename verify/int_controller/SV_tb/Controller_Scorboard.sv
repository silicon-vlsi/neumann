class Controller_Scoreboard;
    mailbox #(Controller_Transaction) mon2scb;
    int pass_count  = 0;
    int fail_count  = 0;
    int total_count = 0;

    typedef enum logic [1:0] {IDLE = 2'b00, IRQ_PENDING = 2'b01, IRQ_DONE = 2'b10} state_e;

    state_e     exp_state;
    logic [4:0] exp_id;

    function new(mailbox #(Controller_Transaction) mon2scb);
        this.mon2scb = mon2scb;
        reset_model();
    endfunction

    function void reset_model();
        exp_state = IDLE;
        exp_id    = 5'b0;
    endfunction

    task run();
        Controller_Transaction tx;
        forever begin
            mon2scb.get(tx);
            total_count++;
            if (tx.rst_n === 1'b0)
                reset_model();
            check(tx);
            if (tx.rst_n !== 1'b0)
                predict(tx);
        end
    endtask

    function void check(Controller_Transaction tx);
        logic exp_req;
        exp_req = (exp_state == IRQ_PENDING);
        if (tx.irq_req_ctrl_o === exp_req && tx.irq_id_ctrl_o === exp_id)
            pass_count++;
        else begin
            fail_count++;
            $error("[SCB] MISMATCH state=%s exp_req=%b got_req=%b exp_id=%0d got_id=%0d",
                   exp_state.name(), exp_req, tx.irq_req_ctrl_o, exp_id, tx.irq_id_ctrl_o);
        end
    endfunction

    function void predict(Controller_Transaction tx);
        case (exp_state)
            IDLE: begin
                if (tx.m_IE_i && tx.irq_i) begin
                    exp_state = IRQ_PENDING;
                    exp_id    = tx.irq_id_i;
                end
            end
            IRQ_PENDING: begin
                if (tx.ctrl_ack_i)
                    exp_state = IRQ_DONE;
                else if (tx.ctrl_kill_i)
                    exp_state = IDLE;
            end
            IRQ_DONE: exp_state = IDLE;
            default : exp_state = IDLE;
        endcase
    endfunction

    task report();
        $display("==========================================");
        $display("[SCB] total=%0d pass=%0d fail=%0d",
                 total_count, pass_count, fail_count);
        $display("==========================================");
        if (fail_count == 0 && total_count > 0)
            $display("[SCB] TEST PASSED");
        else
            $display("[SCB] TEST FAILED");
    endtask
endclass
