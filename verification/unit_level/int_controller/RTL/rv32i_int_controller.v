`include "rv32i_defines.vh"
module rv32i_int_controller
(
    input clk,
    input rst_n,
    // irq request to controller
    output irq_req_ctrl_o,
    output [4:0] irq_id_ctrl_o,
    // handshake signals
    input ctrl_ack_i,
    input ctrl_kill_i,
    // external interrupt
    input irq_i,
    input [4:0] irq_id_i,
    input m_IE_i
);

parameter IDLE        = 2'b00;
parameter IRQ_PENDING = 2'b01;
parameter IRQ_DONE    = 2'b10;
reg [1:0] exc_ctrl_cs;

reg [4:0] irq_id_q;
wire irq_enable_ext;
assign irq_enable_ext = m_IE_i;

assign irq_req_ctrl_o = (exc_ctrl_cs == IRQ_PENDING);
assign irq_id_ctrl_o  = irq_id_q;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) 
    begin
        exc_ctrl_cs <= IDLE;
        irq_id_q    <= 5'b0;
    end
    else 
    begin
        case (exc_ctrl_cs)


            IDLE: 
            begin
                if (irq_enable_ext && irq_i) 
                begin
                    exc_ctrl_cs <= IRQ_PENDING;
                    irq_id_q    <= irq_id_i;
                end
            end

            IRQ_PENDING: 
            begin
                if (ctrl_ack_i) 
                begin
                    exc_ctrl_cs <= IRQ_DONE;
                end
                else if (ctrl_kill_i) 
                begin
                    exc_ctrl_cs <= IDLE;
                end
                else 
                begin
                    exc_ctrl_cs <= IRQ_PENDING;
                end
            end
   
            IRQ_DONE: 
            begin
                exc_ctrl_cs <= IDLE;
            end
 
            default: 
            begin
                exc_ctrl_cs <= IDLE;
            end
        endcase
    end
end
endmodule