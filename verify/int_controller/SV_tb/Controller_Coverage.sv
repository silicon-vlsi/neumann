class Controller_Coverage;
    mailbox #(Controller_Transaction) mon2cov;
    Controller_Transaction tx;

    logic       ctrl_ack_i;
    logic       ctrl_kill_i;
    logic       irq_i;
    logic [4:0] irq_id_i;
    logic       m_IE_i;
    logic       irq_req_ctrl_o;
    logic [4:0] irq_id_ctrl_o;

    covergroup cg;
        option.per_instance = 1;

        cp_irq : coverpoint irq_i {
            bins low  = {1'b0};
            bins high = {1'b1};
        }

        cp_mie : coverpoint m_IE_i {
            bins disabled = {1'b0};
            bins enabled  = {1'b1};
        }

        cp_irq_id : coverpoint irq_id_i {
            bins id[] = {[0:31]};
        }

        cp_hs : coverpoint {ctrl_ack_i, ctrl_kill_i} {
            bins none = {2'b00};
            bins kill = {2'b01};
            bins ack  = {2'b10};
            bins both = {2'b11};
        }

        cp_req : coverpoint irq_req_ctrl_o {
            bins idle    = {1'b0};
            bins pending = {1'b1};
        }

        cp_req_trans : coverpoint irq_req_ctrl_o {
            bins rise         = (0 => 1);
            bins fall         = (1 => 0);
            bins hold         = (1 => 1);
            bins back_to_back = (1 => 0 => 1);
        }

        cp_id_o : coverpoint irq_id_ctrl_o {
            bins zero = {0};
            bins low  = {[1:15]};
            bins high = {[16:30]};
            bins max  = {31};
        }

        x_irq_mie : cross cp_irq, cp_mie;

        x_req_hs : cross cp_req, cp_hs;
    endgroup

    function new(mailbox #(Controller_Transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tx);
            ctrl_ack_i     = tx.ctrl_ack_i;
            ctrl_kill_i    = tx.ctrl_kill_i;
            irq_i          = tx.irq_i;
            irq_id_i       = tx.irq_id_i;
            m_IE_i         = tx.m_IE_i;
            irq_req_ctrl_o = tx.irq_req_ctrl_o;
            irq_id_ctrl_o  = tx.irq_id_ctrl_o;
            cg.sample();
        end
    endtask

    function void report();
        $display("==========================================");
        $display("[COV] coverage = %.2f %%", cg.get_coverage());
        $display("==========================================");
    endfunction
endclass
