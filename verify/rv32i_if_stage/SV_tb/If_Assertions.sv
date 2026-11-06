`include "rv32i_defines.vh"
module If_Assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        req_i,
    input logic        pc_set_i,
    input logic        halt_if_i,
    input logic        id_ready_i,
    input logic        clear_instr_valid_i,
    input logic        if_valid_o,
    input logic        instr_valid_id_o,
    input logic [31:0] pc_if_o,
    input logic [31:0] pc_id_o,
    input logic        perf_imiss_o,
    input logic        fetch_valid,
    input logic        branch_req,
    input logic        if_busy_o,
    input logic        prefetch_busy
);

    property p_req_low_halts;
        @(posedge clk) disable iff (rst_n !== 1'b1) (!req_i && fetch_valid) |-> halt_if_i;
    endproperty
    a_req_low_halts : assert property (p_req_low_halts)
        else $error("IF: req_i low with a valid fetch and no halt, instruction would be handed to ID twice");

    property p_if_valid_cond;
        @(posedge clk) disable iff (rst_n !== 1'b1) if_valid_o |-> !halt_if_i && id_ready_i && fetch_valid && !pc_set_i;
    endproperty
    a_if_valid_cond : assert property (p_if_valid_cond)
        else $error("IF: if_valid_o without a valid fetch / while stalled");

    property p_id_load;
        @(posedge clk) disable iff (rst_n !== 1'b1) if_valid_o |=> instr_valid_id_o && (pc_id_o == $past(pc_if_o));
    endproperty
    a_id_load : assert property (p_id_load)
        else $error("IF: IF/ID register not loaded");

    property p_id_clear;
        @(posedge clk) disable iff (rst_n !== 1'b1) (!if_valid_o && clear_instr_valid_i) |=> !instr_valid_id_o;
    endproperty
    a_id_clear : assert property (p_id_clear)
        else $error("IF: instr_valid_id_o not cleared");

    property p_id_hold;
        @(posedge clk) disable iff (rst_n !== 1'b1) (!if_valid_o && !clear_instr_valid_i) |=> $stable(instr_valid_id_o) && $stable(pc_id_o);
    endproperty
    a_id_hold : assert property (p_id_hold)
        else $error("IF: IF/ID register changed without if_valid");

    property p_branch_on_set;
        @(posedge clk) disable iff (rst_n !== 1'b1) pc_set_i |-> branch_req;
    endproperty
    a_branch_on_set : assert property (p_branch_on_set)
        else $error("IF: pc_set did not branch the prefetcher");

    property p_imiss;
        @(posedge clk) disable iff (rst_n !== 1'b1) perf_imiss_o == (!fetch_valid || branch_req);
    endproperty
    a_imiss : assert property (p_imiss)
        else $error("IF: perf_imiss_o wrong");

    property p_busy;
        @(posedge clk) disable iff (rst_n !== 1'b1) if_busy_o == prefetch_busy;
    endproperty
    a_busy : assert property (p_busy)
        else $error("IF: if_busy_o does not follow prefetcher");

    property p_halfword_pc;
        @(posedge clk) disable iff (rst_n !== 1'b1) if_valid_o |-> (pc_if_o[0] == 1'b0);
    endproperty
    a_halfword_pc : assert property (p_halfword_pc)
        else $error("IF: odd pc_if_o");

    c_stall  : cover property (@(posedge clk) fetch_valid && !id_ready_i);
    c_halt   : cover property (@(posedge clk) fetch_valid && halt_if_i);
    c_b2b    : cover property (@(posedge clk) if_valid_o ##1 if_valid_o ##1 if_valid_o);

endmodule

bind rv32i_if_stage If_Assertions u_assert (
    .clk                 (clk),
    .rst_n               (rst_n),
    .req_i               (req_i),
    .pc_set_i            (pc_set_i),
    .halt_if_i           (halt_if_i),
    .id_ready_i          (id_ready_i),
    .clear_instr_valid_i (clear_instr_valid_i),
    .if_valid_o          (if_valid_o),
    .instr_valid_id_o    (instr_valid_id_o),
    .pc_if_o             (pc_if_o),
    .pc_id_o             (pc_id_o),
    .perf_imiss_o        (perf_imiss_o),
    .fetch_valid         (fetch_valid),
    .branch_req          (branch_req),
    .if_busy_o           (if_busy_o),
    .prefetch_busy       (prefetch_busy)
);
