`include "rv32i_defines.vh"
module rv32i_fetch_fifo
(
    input clk,
    input rst_n,
    // control signals
    input clear_i, 
    // input port
    input [31:0] in_addr_i,
    input [31:0] in_rdata_i,
    input  in_valid_i,
    output in_ready_o,
    // output port
    output reg out_valid_o,
    input  out_ready_i,
    output reg [31:0] out_rdata_o,
    output [31:0] out_addr_o,
    output reg out_valid_stored_o
);
    localparam DEPTH = 3; // must be 3 or greater
    reg [31:0] addr_Q  [0:DEPTH-1];
    reg [31:0] rdata_Q [0:DEPTH-1];
    reg valid_Q [0:DEPTH-1];
    reg [31:0] addr_int  [0:DEPTH-1];
    reg [31:0] rdata_int [0:DEPTH-1];
    reg valid_int [0:DEPTH-1];
    reg [31:0] addr_n  [0:DEPTH-1];
    reg [31:0] rdata_n [0:DEPTH-1];
    reg valid_n [0:DEPTH-1];
    wire [31:0] addr_next;
    wire [31:0] rdata;
    wire [31:0] rdata_unaligned;
    wire valid;
    wire valid_unaligned;
    wire aligned_is_compressed;
    wire unaligned_is_compressed;
    wire aligned_is_compressed_st;
    wire unaligned_is_compressed_st;
    assign rdata = valid_Q[0] ? rdata_Q[0] : in_rdata_i;
    assign valid = valid_Q[0] | in_valid_i;
    assign rdata_unaligned = valid_Q[1] ? {rdata_Q[1][15:0], rdata[31:16]} : {in_rdata_i[15:0], rdata[31:16]};
    assign valid_unaligned = valid_Q[1] | (valid_Q[0] & in_valid_i);
    assign unaligned_is_compressed = (rdata[17:16] != 2'b11);
    assign aligned_is_compressed = (rdata[1:0] != 2'b11);
    assign unaligned_is_compressed_st = (rdata_Q[0][17:16] != 2'b11);
    assign aligned_is_compressed_st = (rdata_Q[0][1:0] != 2'b11);
    always @(*) 
    begin
        if (out_addr_o[1]) 
        begin
            out_rdata_o = rdata_unaligned;
            if (unaligned_is_compressed)
                out_valid_o = valid;
            else
                out_valid_o = valid_unaligned;
        end 
        else 
        begin
            out_rdata_o = rdata;
            out_valid_o = valid;
        end
    end
    assign out_addr_o = valid_Q[0] ? addr_Q[0] : in_addr_i;
    always @(*) 
    begin
        out_valid_stored_o = 1'b1;
        if (out_addr_o[1]) 
        begin
            if (unaligned_is_compressed_st)
                out_valid_stored_o = 1'b1;
            else
                out_valid_stored_o = valid_Q[1];
        end 
        else 
        begin
            out_valid_stored_o = valid_Q[0];
        end
    end
    assign in_ready_o = ~valid_Q[DEPTH-2];
    always @(*) 
    begin 
        addr_int[0]  = addr_Q[0];
        addr_int[1]  = addr_Q[1];
        addr_int[2]  = addr_Q[2];
        rdata_int[0] = rdata_Q[0];
        rdata_int[1] = rdata_Q[1];
        rdata_int[2] = rdata_Q[2];
        valid_int[0] = valid_Q[0];
        valid_int[1] = valid_Q[1];
        valid_int[2] = valid_Q[2];
        if (in_valid_i) 
        begin
            if (~valid_Q[0])
            begin
                addr_int[0]  = in_addr_i;
                rdata_int[0] = in_rdata_i;
                valid_int[0] = 1'b1;
            end 
            else if (~valid_Q[1]) 
            begin
                addr_int[1]  = in_addr_i;
                rdata_int[1] = in_rdata_i;
                valid_int[1] = 1'b1;
            end 
            else if (~valid_Q[2]) 
            begin
                addr_int[2]  = in_addr_i;
                rdata_int[2] = in_rdata_i;
                valid_int[2] = 1'b1;
            end
        end
    end
    assign addr_next = {addr_int[0][31:2], 2'b00} + 32'h4;
    always @(*) 
    begin 
        addr_n[0]  = addr_int[0];
        addr_n[1]  = addr_int[1];
        addr_n[2]  = addr_int[2];
        rdata_n[0] = rdata_int[0];
        rdata_n[1] = rdata_int[1];
        rdata_n[2] = rdata_int[2];
        valid_n[0] = valid_int[0];
        valid_n[1] = valid_int[1];
        valid_n[2] = valid_int[2];

        if (out_ready_i && out_valid_o) begin
            if (addr_int[0][1]) begin
                if (unaligned_is_compressed) begin
                    addr_n[0] = {addr_next[31:2], 2'b00};
                end else begin
                    addr_n[0] = {addr_next[31:2], 2'b10};
                end
                rdata_n[0] = rdata_int[1];
                rdata_n[1] = rdata_int[2];
                rdata_n[2] = 32'b0;
                valid_n[0] = valid_int[1];
                valid_n[1] = valid_int[2];
                valid_n[2] = 1'b0;
            end 
            else 
            begin
                if(aligned_is_compressed) 
                begin
                    addr_n[0] = {addr_int[0][31:2], 2'b10};
                end 
                else 
                begin
                    addr_n[0]  = {addr_next[31:2], 2'b00};
                    rdata_n[0] = rdata_int[1];
                    rdata_n[1] = rdata_int[2];
                    rdata_n[2] = 32'b0;
                    valid_n[0] = valid_int[1];
                    valid_n[1] = valid_int[2];
                    valid_n[2] = 1'b0;
                end
            end
        end
    end
    integer i;
    always @(posedge clk or negedge rst_n)
     begin
        if (!rst_n) 
        begin
            for (i = 0; i < DEPTH; i = i + 1) 
            begin
                addr_Q[i]  <= 32'b0;
                rdata_Q[i] <= 32'b0;
                valid_Q[i] <= 1'b0;
            end
        end 
        else 
        begin
            if (clear_i)
            begin
                for (i = 0; i < DEPTH; i = i + 1) 
                begin
                    valid_Q[i] <= 1'b0;
                end
            end 
            else 
            begin
                for (i = 0; i < DEPTH; i = i + 1) 
                begin
                    addr_Q[i]  <= addr_n[i];
                    rdata_Q[i] <= rdata_n[i];
                    valid_Q[i] <= valid_n[i];
                end
            end
        end
    end
endmodule