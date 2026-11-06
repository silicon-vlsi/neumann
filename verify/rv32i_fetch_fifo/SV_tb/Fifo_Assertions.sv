module Fifo_Assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        clear_i,
    input logic [31:0] in_addr_i,
    input logic [31:0] in_rdata_i,
    input logic        in_valid_i,
    input logic        in_ready_o,
    input logic        out_valid_o,
    input logic        out_ready_i,
    input logic [31:0] out_rdata_o,
    input logic [31:0] out_addr_o,
    input logic        vq0,
    input logic        vq1,
    input logic        vq2
);

    property p_ready;
        @(posedge clk) disable iff (rst_n !== 1'b1) in_ready_o == !vq1;
    endproperty
    a_ready : assert property (p_ready)
        else $error("FIFO: in_ready_o does not match occupancy");

    property p_ordered;
        @(posedge clk) disable iff (rst_n !== 1'b1) (!vq1 || vq0) && (!vq2 || vq1);
    endproperty
    a_ordered : assert property (p_ordered)
        else $error("FIFO: valid bits are not packed from entry 0");

    property p_no_overflow;
        @(posedge clk) disable iff (rst_n !== 1'b1) (in_valid_i && !clear_i) |-> !vq2;
    endproperty
    a_no_overflow : assert property (p_no_overflow)
        else $error("FIFO: push while full, word dropped");

    property p_clear;
        @(posedge clk) disable iff (rst_n !== 1'b1) clear_i |=> !vq0;
    endproperty
    a_clear : assert property (p_clear)
        else $error("FIFO: clear did not empty the fifo");

    property p_hold;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (out_valid_o && !out_ready_i && !clear_i) |=> (out_valid_o || clear_i) && (out_addr_o == $past(out_addr_o));
    endproperty
    a_hold : assert property (p_hold)
        else $error("FIFO: output changed while stalled");

    property p_halfword;
        @(posedge clk) disable iff (rst_n !== 1'b1) out_valid_o |-> (out_addr_o[0] == 1'b0);
    endproperty
    a_halfword : assert property (p_halfword)
        else $error("FIFO: odd output address");

    property p_no_x;
        @(posedge clk) disable iff (rst_n !== 1'b1) out_valid_o |-> !$isunknown({out_addr_o, out_rdata_o[15:0]});
    endproperty
    a_no_x : assert property (p_no_x)
        else $error("FIFO: X on valid output");

    c_full      : cover property (@(posedge clk) vq2);
    c_bypass    : cover property (@(posedge clk) !vq0 && in_valid_i && out_valid_o && out_ready_i);
    c_unaligned : cover property (@(posedge clk) out_valid_o && out_ready_i && out_addr_o[1] && (out_rdata_o[1:0] == 2'b11));

endmodule

bind rv32i_fetch_fifo Fifo_Assertions u_assert (
    .clk         (clk),
    .rst_n       (rst_n),
    .clear_i     (clear_i),
    .in_addr_i   (in_addr_i),
    .in_rdata_i  (in_rdata_i),
    .in_valid_i  (in_valid_i),
    .in_ready_o  (in_ready_o),
    .out_valid_o (out_valid_o),
    .out_ready_i (out_ready_i),
    .out_rdata_o (out_rdata_o),
    .out_addr_o  (out_addr_o),
    .vq0         (valid_Q[0]),
    .vq1         (valid_Q[1]),
    .vq2         (valid_Q[2])
);
