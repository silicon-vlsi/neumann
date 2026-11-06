`include "rv32i_defines.vh"
module Id_Assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        id_ready_o,
    input logic        id_valid_o,
    input logic        halt_id,
    input logic        clear_instr_valid_o,
    input logic        data_req_id,
    input logic        jump_in_id,
    input logic        branch_in_id,
    input logic        branch_decision_i,
    input logic        ex_ready_i,
    input logic        id_wb_fsm_cs,
    input logic        regfile_we_mux,
    input logic [4:0]  regfile_waddr_mux,
    input logic        dbg_reg_wreq_i,
    input logic        pc_set_o,
    input logic [2:0]  pc_mux_o,
    input logic        branch_set_q,
    input logic        is_decoding_o
);

    property p_valid_ready;
        @(posedge clk) disable iff (rst_n !== 1'b1) id_valid_o |-> id_ready_o && !halt_id;
    endproperty
    a_valid_ready : assert property (p_valid_ready)
        else $error("ID: id_valid_o without id_ready_o");

    property p_clear;
        @(posedge clk) disable iff (rst_n !== 1'b1) clear_instr_valid_o == (id_ready_o || halt_id);
    endproperty
    a_clear : assert property (p_clear)
        else $error("ID: clear_instr_valid_o wrong");

    property p_load_stall;
        @(posedge clk) disable iff (rst_n !== 1'b1) (id_wb_fsm_cs == 1'b0) && data_req_id |-> !id_ready_o;
    endproperty
    a_load_stall : assert property (p_load_stall)
        else $error("ID: load/store did not stall in its first cycle");

    property p_jump_stall;
        @(posedge clk) disable iff (rst_n !== 1'b1) (id_wb_fsm_cs == 1'b0) && !data_req_id && !branch_in_id && jump_in_id |-> !id_ready_o;
    endproperty
    a_jump_stall : assert property (p_jump_stall)
        else $error("ID: jump did not stall in its first cycle");

    property p_wait_done;
        @(posedge clk) disable iff (rst_n !== 1'b1) (id_wb_fsm_cs == 1'b1) && ex_ready_i |=> (id_wb_fsm_cs == 1'b0);
    endproperty
    a_wait_done : assert property (p_wait_done)
        else $error("ID: WAIT_MULTICYCLE did not end on ex_ready");

    property p_taken_branch;
        @(posedge clk) disable iff (rst_n !== 1'b1) (id_wb_fsm_cs == 1'b0) && !data_req_id && branch_in_id && branch_decision_i |=> branch_set_q;
    endproperty
    a_taken_branch : assert property (p_taken_branch)
        else $error("ID: taken branch did not set branch_set_q");

    property p_branch_redirect;
        @(posedge clk) disable iff (rst_n !== 1'b1) branch_set_q && is_decoding_o |-> pc_set_o && (pc_mux_o == `PC_JUMP);
    endproperty
    a_branch_redirect : assert property (p_branch_redirect)
        else $error("ID: taken branch not redirected");

    property p_no_x0_write;
        @(posedge clk) disable iff (rst_n !== 1'b1) regfile_we_mux && !dbg_reg_wreq_i |-> !$isunknown(regfile_waddr_mux);
    endproperty
    a_no_x0_write : assert property (p_no_x0_write)
        else $error("ID: unknown write address");

    c_load    : cover property (@(posedge clk) (id_wb_fsm_cs == 1'b0) && data_req_id);
    c_ex_wait : cover property (@(posedge clk) (id_wb_fsm_cs == 1'b1) && !ex_ready_i);
    c_taken   : cover property (@(posedge clk) branch_set_q);
    c_dbg_wr  : cover property (@(posedge clk) dbg_reg_wreq_i);

endmodule

bind rv32i_id_stage Id_Assertions u_assert (
    .clk                 (clk),
    .rst_n               (rst_n),
    .id_ready_o          (id_ready_o),
    .id_valid_o          (id_valid_o),
    .halt_id             (halt_id),
    .clear_instr_valid_o (clear_instr_valid_o),
    .data_req_id         (data_req_id),
    .jump_in_id          (jump_in_id),
    .branch_in_id        (branch_in_id),
    .branch_decision_i   (branch_decision_i),
    .ex_ready_i          (ex_ready_i),
    .id_wb_fsm_cs        (id_wb_fsm_cs),
    .regfile_we_mux      (regfile_we_mux),
    .regfile_waddr_mux   (regfile_waddr_mux),
    .dbg_reg_wreq_i      (dbg_reg_wreq_i),
    .pc_set_o            (pc_set_o),
    .pc_mux_o            (pc_mux_o),
    .branch_set_q        (branch_set_q),
    .is_decoding_o       (is_decoding_o)
);
