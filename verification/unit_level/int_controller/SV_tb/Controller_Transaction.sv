class Controller_Transaction;
    rand logic  rst_n;
    rand logic  ctrl_ack_i;
    rand logic  ctrl_kill_i;
    rand logic  irq_i;
    rand logic  [4:0] irq_id_i;
    rand logic  m_IE_i;

    logic irq_req_ctrl_o;
    logic [4:0] irq_id_ctrl_o;

    constraint c_rst 
    { 
        rst_n dist {1 := 95, 0 := 5}; 
    }
    constraint c_irq 
    { 
        irq_i dist {1 := 70, 0 := 30}; 
    }
    constraint c_hs  
    {
        ctrl_ack_i dist {1 := 40, 0 := 60};
        ctrl_kill_i dist {1 := 20, 0 := 80}; 
    }
    function void display(string tag="TX");
        $display("[%s] rst=%b ack=%b kill=%b irq=%b id=%0d m_IE=%b | req_o=%b id_o=%0d",tag, rst_n, ctrl_ack_i, ctrl_kill_i, irq_i, irq_id_i, m_IE_i,irq_req_ctrl_o, irq_id_ctrl_o);
    endfunction

    function Controller_Transaction do_copy();
    Controller_Transaction copy;
    copy = new();
    copy.rst_n = this.rst_n;
    copy.ctrl_ack_i=this.ctrl_ack_i;
    copy.ctrl_kill_i=this.ctrl_kill_i;
    copy.irq_i=this.irq_i;
    copy.irq_id_i=this.irq_id_i;
    copy.m_IE_i=this.m_IE_i;
    copy.irq_id_ctrl_o=this.irq_id_ctrl_o;
    copy.irq_req_ctrl_o=this.irq_req_ctrl_o;
    return copy;
    endfunction
endclass

