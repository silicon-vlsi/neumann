module Reg_Assertions #(parameter DATA_WIDTH = 32) (
    input logic                  clk,
    input logic                  rst_n,
    input logic                  test_en_i,
    input logic [4:0]            raddr_a_i,
    input logic [DATA_WIDTH-1:0] rdata_a_o,
    input logic [4:0]            raddr_b_i,
    input logic [DATA_WIDTH-1:0] rdata_b_o,
    input logic [4:0]            waddr_a_i,
    input logic [DATA_WIDTH-1:0] wdata_a_i,
    input logic                  we_a_i
);

    property p_x0_a;
        @(posedge clk) (raddr_a_i == 5'd0) |-> (rdata_a_o == '0);
    endproperty
    a_x0_a : assert property (p_x0_a)
        else $error("REGFILE: x0 read on port A is not zero (%h)", rdata_a_o);

    property p_x0_b;
        @(posedge clk) (raddr_b_i == 5'd0) |-> (rdata_b_o == '0);
    endproperty
    a_x0_b : assert property (p_x0_b)
        else $error("REGFILE: x0 read on port B is not zero (%h)", rdata_b_o);

    property p_write_read_a;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (we_a_i && waddr_a_i != 5'd0) |=> ((raddr_a_i != $past(waddr_a_i)) || (rdata_a_o == $past(wdata_a_i)));
    endproperty
    a_write_read_a : assert property (p_write_read_a)
        else $error("REGFILE: write to x%0d not visible on port A next cycle", $past(waddr_a_i));

    property p_write_read_b;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (we_a_i && waddr_a_i != 5'd0) |=> ((raddr_b_i != $past(waddr_a_i)) || (rdata_b_o == $past(wdata_a_i)));
    endproperty
    a_write_read_b : assert property (p_write_read_b)
        else $error("REGFILE: write to x%0d not visible on port B next cycle", $past(waddr_a_i));

    property p_same_addr_same_data;
        @(posedge clk) (raddr_a_i == raddr_b_i) |-> (rdata_a_o === rdata_b_o);
    endproperty
    a_same_addr_same_data : assert property (p_same_addr_same_data)
        else $error("REGFILE: ports A and B disagree on x%0d", raddr_a_i);

    property p_no_write_hold;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (!we_a_i && !test_en_i && (raddr_a_i == $past(raddr_a_i)) && !$past(we_a_i) && !$past(test_en_i)) |-> $stable(rdata_a_o);
    endproperty
    a_no_write_hold : assert property (p_no_write_hold)
        else $error("REGFILE: x%0d changed without a write", raddr_a_i);

    c_write_x0   : cover property (@(posedge clk) we_a_i && waddr_a_i == 5'd0);
    c_write_x31  : cover property (@(posedge clk) we_a_i && waddr_a_i == 5'd31);
    c_test_en_we : cover property (@(posedge clk) test_en_i && we_a_i);
    c_raw        : cover property (@(posedge clk) we_a_i ##1 (raddr_a_i == $past(waddr_a_i)));

endmodule

bind rv32i_register_file Reg_Assertions #(.DATA_WIDTH(DATA_WIDTH)) u_assert (
    .clk       (clk),
    .rst_n     (rst_n),
    .test_en_i (test_en_i),
    .raddr_a_i (raddr_a_i),
    .rdata_a_o (rdata_a_o),
    .raddr_b_i (raddr_b_i),
    .rdata_b_o (rdata_b_o),
    .waddr_a_i (waddr_a_i),
    .wdata_a_i (wdata_a_i),
    .we_a_i    (we_a_i)
);
