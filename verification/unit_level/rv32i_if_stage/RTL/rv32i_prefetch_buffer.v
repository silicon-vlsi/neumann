`include "rv32i_defines.vh"
module rv32i_prefetch_buffer
(
    input clk,
    input rst_n,
    input req_i,
    input branch_i,
    input  [31:0] addr_i,
    input ready_i,
    output valid_o,
    output [31:0] rdata_o,
    output [31:0] addr_o,
    output reg instr_req_o,
    input  instr_gnt_i,
    output reg [31:0] instr_addr_o,
    input [31:0] instr_rdata_i,
    input instr_rvalid_i,
    output busy_o
);
    localparam IDLE         = 2'b00;
    localparam WAIT_GNT     = 2'b01;
    localparam WAIT_RVALID  = 2'b10;
    localparam WAIT_ABORTED = 2'b11;
    reg [1:0] CS, NS;
    reg  [31:0] instr_addr_q;
    wire [31:0] fetch_addr;
    reg addr_valid;
    reg fifo_valid;
    wire fifo_ready;
    wire fifo_clear;
    wire valid_stored;
    assign busy_o = (CS != IDLE) | instr_req_o;
    rv32i_fetch_fifo fifo_i
    (
        .clk(clk),
        .rst_n(rst_n),
        .clear_i(fifo_clear),
        .in_addr_i(instr_addr_q),
        .in_rdata_i(instr_rdata_i),
        .in_valid_i(fifo_valid),
        .in_ready_o(fifo_ready),
        .out_valid_o(valid_o),
        .out_ready_i(ready_i),
        .out_rdata_o(rdata_o),
        .out_addr_o(addr_o),
        .out_valid_stored_o(valid_stored)
    );
    assign fetch_addr = {instr_addr_q[31:2], 2'b00} + 32'd4;
    assign fifo_clear = branch_i;
    always @(*) 
    begin
        instr_req_o  = 1'b0;
        instr_addr_o = fetch_addr;
        fifo_valid   = 1'b0;
        addr_valid   = 1'b0;
        NS = CS;
        case (CS)
            IDLE: 
            begin
                instr_addr_o = fetch_addr;
                instr_req_o  = 1'b0;
                if (branch_i)
                    instr_addr_o = addr_i;
                if (req_i & (fifo_ready | branch_i)) 
                begin
                    instr_req_o = 1'b1;
                    addr_valid  = 1'b1;
                    if (instr_gnt_i)
                        NS = WAIT_RVALID;
                    else
                        NS = WAIT_GNT;
                end
            end
            WAIT_GNT: 
            begin
                instr_addr_o = instr_addr_q;
                instr_req_o  = 1'b1;
                if (branch_i) 
                begin
                    instr_addr_o = addr_i;
                    addr_valid   = 1'b1;
                end
                if (instr_gnt_i)
                    NS = WAIT_RVALID;
                else
                    NS = WAIT_GNT;
            end
            WAIT_RVALID: 
            begin
                instr_addr_o = fetch_addr;
                if (branch_i)
                    instr_addr_o = addr_i;
                if (req_i & (fifo_ready | branch_i)) 
                begin
                    if(instr_rvalid_i) 
                    begin
                        instr_req_o = 1'b1;
                        fifo_valid  = 1'b1;
                        addr_valid  = 1'b1;
                        if (instr_gnt_i)
                            NS = WAIT_RVALID;
                        else
                            NS = WAIT_GNT;
                    end 
                    else 
                    begin
                        if (branch_i) 
                        begin
                            addr_valid = 1'b1;
                            NS = WAIT_ABORTED;
                        end
                    end
                end 
                else 
                begin
                    if (instr_rvalid_i) 
                    begin
                        fifo_valid = 1'b1;
                        NS = IDLE;
                    end
                end
            end
            WAIT_ABORTED: 
            begin
                instr_addr_o = instr_addr_q;
                if (branch_i) 
                begin
                    instr_addr_o = addr_i;
                    addr_valid   = 1'b1;
                end
                if (instr_rvalid_i) 
                begin
                    instr_req_o = 1'b1;
                    if (instr_gnt_i)
                        NS = WAIT_RVALID;
                    else
                        NS = WAIT_GNT;
                end
            end
            default: 
            begin
                NS = IDLE;
                instr_req_o = 1'b0;
            end
        endcase
    end
    always @(posedge clk or negedge rst_n)
     begin
        if (!rst_n) 
        begin
            CS <= IDLE;
            instr_addr_q <= 32'b0;
        end 
        else 
        begin
            CS <= NS;
            if (addr_valid)
                instr_addr_q <= instr_addr_o;
        end
    end
endmodule