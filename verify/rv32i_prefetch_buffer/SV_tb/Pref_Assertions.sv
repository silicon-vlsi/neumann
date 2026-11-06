module Pref_Assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        req_i,
    input logic        branch_i,
    input logic [31:0] addr_i,
    input logic        instr_req_o,
    input logic        instr_gnt_i,
    input logic [31:0] instr_addr_o,
    input logic        instr_rvalid_i,
    input logic        busy_o,
    input logic [1:0]  CS
);

    localparam IDLE         = 2'b00;
    localparam WAIT_GNT     = 2'b01;
    localparam WAIT_RVALID  = 2'b10;
    localparam WAIT_ABORTED = 2'b11;

    property p_branch_needs_req;
        @(posedge clk) disable iff (rst_n !== 1'b1) branch_i |-> req_i;
    endproperty
    a_branch_needs_req : assert property (p_branch_needs_req)
        else $error("PREF: branch_i without req_i, the target would be lost");

    property p_busy;
        @(posedge clk) disable iff (rst_n !== 1'b1) busy_o == ((CS != IDLE) || instr_req_o);
    endproperty
    a_busy : assert property (p_busy)
        else $error("PREF: busy_o wrong in state %b", CS);

    property p_wait_gnt_req;
        @(posedge clk) disable iff (rst_n !== 1'b1) (CS == WAIT_GNT) |-> instr_req_o;
    endproperty
    a_wait_gnt_req : assert property (p_wait_gnt_req)
        else $error("PREF: request dropped before grant");

    property p_wait_gnt_addr;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (instr_req_o && !instr_gnt_i && !branch_i) |=> !instr_req_o || branch_i || (instr_addr_o == $past(instr_addr_o));
    endproperty
    a_wait_gnt_addr : assert property (p_wait_gnt_addr)
        else $error("PREF: address changed while waiting for grant");

    property p_branch_addr;
        @(posedge clk) disable iff (rst_n !== 1'b1) (branch_i && instr_req_o) |-> (instr_addr_o == addr_i);
    endproperty
    a_branch_addr : assert property (p_branch_addr)
        else $error("PREF: branch request not sent to branch target");

    property p_grant_next;
        @(posedge clk) disable iff (rst_n !== 1'b1) (instr_req_o && instr_gnt_i) |=> (CS == WAIT_RVALID);
    endproperty
    a_grant_next : assert property (p_grant_next)
        else $error("PREF: granted request not waiting for rvalid");

    property p_abort;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (CS == WAIT_RVALID) && branch_i && req_i && !instr_rvalid_i |=> (CS == WAIT_ABORTED);
    endproperty
    a_abort : assert property (p_abort)
        else $error("PREF: branch during outstanding fetch did not abort");

    property p_idle_quiet;
        @(posedge clk) disable iff (rst_n !== 1'b1) (CS == IDLE) && !req_i |-> !instr_req_o;
    endproperty
    a_idle_quiet : assert property (p_idle_quiet)
        else $error("PREF: request issued without req_i");

    c_aborted  : cover property (@(posedge clk) CS == WAIT_ABORTED);
    c_wait_gnt : cover property (@(posedge clk) CS == WAIT_GNT);
    c_b2b      : cover property (@(posedge clk) (CS == WAIT_RVALID) && instr_rvalid_i && instr_req_o && instr_gnt_i);

endmodule

bind rv32i_prefetch_buffer Pref_Assertions u_assert (
    .clk            (clk),
    .rst_n          (rst_n),
    .req_i          (req_i),
    .branch_i       (branch_i),
    .addr_i         (addr_i),
    .instr_req_o    (instr_req_o),
    .instr_gnt_i    (instr_gnt_i),
    .instr_addr_o   (instr_addr_o),
    .instr_rvalid_i (instr_rvalid_i),
    .busy_o         (busy_o),
    .CS             (CS)
);
