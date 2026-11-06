module Dbg_Assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        debug_req_i,
    input logic        debug_we_i,
    input logic [14:0] debug_addr_i,
    input logic        debug_gnt_o,
    input logic        debug_rvalid_o,
    input logic        debug_halted_o,
    input logic        stall_o,
    input logic        dbg_req_o,
    input logic        dbg_ack_i,
    input logic        regfile_wreq_o,
    input logic        regfile_rreq_o,
    input logic        csr_we_o,
    input logic        jump_req_o,
    input logic [1:0]  stall_cs
);

    property p_rvalid;
        @(posedge clk) disable iff (rst_n !== 1'b1) debug_gnt_o |=> debug_rvalid_o;
    endproperty
    a_rvalid : assert property (p_rvalid)
        else $error("DBG: grant not followed by rvalid");

    property p_rvalid_only_after_gnt;
        @(posedge clk) disable iff (rst_n !== 1'b1) debug_rvalid_o |-> $past(debug_gnt_o);
    endproperty
    a_rvalid_only_after_gnt : assert property (p_rvalid_only_after_gnt)
        else $error("DBG: rvalid without a grant");

    property p_gnt_needs_req;
        @(posedge clk) disable iff (rst_n !== 1'b1) debug_gnt_o |-> debug_req_i;
    endproperty
    a_gnt_needs_req : assert property (p_gnt_needs_req)
        else $error("DBG: grant without request");

    property p_csr_write_two_cycles;
        @(posedge clk) disable iff (rst_n !== 1'b1)
        (debug_req_i && debug_we_i && debug_addr_i[14] && !$past(debug_req_i && debug_we_i && debug_addr_i[14] && !debug_gnt_o)) |-> !debug_gnt_o;
    endproperty
    a_csr_write_two_cycles : assert property (p_csr_write_two_cycles)
        else $error("DBG: CSR write granted in its first cycle");

    property p_stall_halted;
        @(posedge clk) disable iff (rst_n !== 1'b1) stall_o |-> debug_halted_o;
    endproperty
    a_stall_halted : assert property (p_stall_halted)
        else $error("DBG: stall without halted");

    property p_halt_after_ack;
        @(posedge clk) disable iff (rst_n !== 1'b1) (stall_cs == 2'd1) && dbg_ack_i && !$isunknown(dbg_ack_i) |=> (stall_cs == 2'd2) || (stall_cs == 2'd0);
    endproperty
    a_halt_after_ack : assert property (p_halt_after_ack)
        else $error("DBG: ack in HALT_REQ did not halt");

    property p_halt_req;
        @(posedge clk) disable iff (rst_n !== 1'b1) (stall_cs == 2'd1) |-> dbg_req_o;
    endproperty
    a_halt_req : assert property (p_halt_req)
        else $error("DBG: dbg_req_o low while requesting halt");

    property p_gpr_write_halted;
        @(posedge clk) disable iff (rst_n !== 1'b1) regfile_wreq_o |-> debug_halted_o;
    endproperty
    a_gpr_write_halted : assert property (p_gpr_write_halted)
        else $error("DBG: GPR write while core running");

    property p_jump_after_halted;
        @(posedge clk) disable iff (rst_n !== 1'b1) jump_req_o |-> $past(debug_halted_o);
    endproperty
    a_jump_after_halted : assert property (p_jump_after_halted)
        else $error("DBG: NPC jump requested while running");

    property p_state_legal;
        @(posedge clk) disable iff (rst_n !== 1'b1) stall_cs != 2'd3;
    endproperty
    a_state_legal : assert property (p_state_legal)
        else $error("DBG: illegal stall state");

    c_halt     : cover property (@(posedge clk) debug_halted_o);
    c_csr_wr   : cover property (@(posedge clk) csr_we_o);
    c_gpr_rd   : cover property (@(posedge clk) regfile_rreq_o);
    c_jump     : cover property (@(posedge clk) jump_req_o);

endmodule

bind rv32i_debug_unit Dbg_Assertions u_assert (
    .clk            (clk),
    .rst_n          (rst_n),
    .debug_req_i    (debug_req_i),
    .debug_we_i     (debug_we_i),
    .debug_addr_i   (debug_addr_i),
    .debug_gnt_o    (debug_gnt_o),
    .debug_rvalid_o (debug_rvalid_o),
    .debug_halted_o (debug_halted_o),
    .stall_o        (stall_o),
    .dbg_req_o      (dbg_req_o),
    .dbg_ack_i      (dbg_ack_i),
    .regfile_wreq_o (regfile_wreq_o),
    .regfile_rreq_o (regfile_rreq_o),
    .csr_we_o       (csr_we_o),
    .jump_req_o     (jump_req_o),
    .stall_cs       (stall_cs)
);
