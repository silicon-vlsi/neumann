`include "rv32i_defines.vh"

module lsu_assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        data_req_o,
    input logic        data_gnt_i,
    input logic        data_rvalid_i,
    input logic        data_err_i,
    input logic [31:0] data_addr_o,
    input logic        data_we_o,
    input logic [3:0]  data_be_o,
    input logic [31:0] data_wdata_o,
    input logic [31:0] data_rdata_i,
    input logic        data_we_ex_i,
    input logic [1:0]  data_type_ex_i,
    input logic [31:0] data_wdata_ex_i,
    input logic [1:0]  data_reg_offset_ex_i,
    input logic        data_sign_ext_ex_i,
    input logic [31:0] data_rdata_ex_o,
    input logic        data_req_ex_i,
    input logic [31:0] adder_result_ex_i,
    input logic        data_misaligned_o,
    input logic [31:0] misaligned_addr_o,
    input logic        load_err_o,
    input logic        store_err_o,
    input logic        lsu_update_addr_o,
    input logic        data_valid_o,
    input logic        busy_o,
    input logic [2:0]  CS
);

    localparam IDLE            = 3'b000;
    localparam WAIT_GNT_MIS    = 3'b001;
    localparam WAIT_RVALID_MIS = 3'b010;
    localparam WAIT_GNT        = 3'b011;
    localparam WAIT_RVALID     = 3'b100;

    property p_state_legal;
        @(posedge clk) disable iff (!rst_n)
        CS inside {IDLE, WAIT_GNT_MIS, WAIT_RVALID_MIS, WAIT_GNT, WAIT_RVALID};
    endproperty
    a_state_legal : assert property (p_state_legal)
        else $error("LSU: illegal FSM state %b", CS);

    property p_req_stable;
        @(posedge clk) disable iff (!rst_n)
        (data_req_o && !data_gnt_i) |=> data_req_o;
    endproperty
    a_req_stable : assert property (p_req_stable)
        else $error("LSU: data_req_o dropped before grant");

    int outstanding;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                     outstanding <= 0;
        else begin
            case ({data_gnt_i, data_rvalid_i})
                2'b10: outstanding <= outstanding + 1;
                2'b01: outstanding <= (outstanding>0)? outstanding-1 : 0;
                default: ;
            endcase
        end
    end
    property p_rvalid_has_gnt;
        @(posedge clk) disable iff (!rst_n)
        data_rvalid_i |-> (outstanding > 0) || data_gnt_i;
    endproperty
    a_rvalid_has_gnt : assert property (p_rvalid_has_gnt)
        else $error("LSU: rvalid with no outstanding grant");

    property p_addr_stable;
        @(posedge clk) disable iff (!rst_n)
        (data_req_o && !data_gnt_i) |=> $stable(data_addr_o);
    endproperty
    a_addr_stable : assert property (p_addr_stable)
        else $error("LSU: data_addr_o changed while waiting for grant");

    property p_be_nonzero;
        @(posedge clk) disable iff (!rst_n)
        data_req_o |-> (data_be_o != 4'b0000);
    endproperty
    a_be_nonzero : assert property (p_be_nonzero)
        else $error("LSU: data_be_o all-zero during request");

    property p_word_aligned_be;
        @(posedge clk) disable iff (!rst_n)
        (data_req_o && data_type_ex_i==2'b00 && adder_result_ex_i[1:0]==2'b00
         && !data_misaligned_o)
        |-> (data_be_o == 4'b1111);
    endproperty
    a_word_be : assert property (p_word_aligned_be)
        else $error("LSU: aligned word BE != 1111 (%b)", data_be_o);

    property p_mis_valid;
        @(posedge clk) disable iff (!rst_n)
        data_misaligned_o |->
        ( (data_type_ex_i==2'b00 && adder_result_ex_i[1:0]!=2'b00) ||
          (data_type_ex_i==2'b01 && adder_result_ex_i[1:0]==2'b11) ||
          (CS inside {WAIT_RVALID_MIS, WAIT_GNT_MIS}) );
    endproperty
    a_mis_valid : assert property (p_mis_valid)
        else $error("LSU: misaligned asserted for aligned access");

    property p_valid_when_rvalid;
        @(posedge clk) disable iff (!rst_n)
        data_valid_o |-> (data_rvalid_i && (CS == WAIT_RVALID));
    endproperty
    a_valid_when_rvalid : assert property (p_valid_when_rvalid)
        else $error("LSU: data_valid_o without rvalid/WAIT_RVALID");

    property p_idle_gnt_to_rvalid;
        @(posedge clk) disable iff (!rst_n)
        (CS==IDLE && data_req_ex_i && data_gnt_i && !data_misaligned_o)
        |=> (CS == WAIT_RVALID);
    endproperty
    a_idle_to_rvalid : assert property (p_idle_gnt_to_rvalid)
        else $error("LSU: IDLE+gnt did not go to WAIT_RVALID");

    property p_no_x_out;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown({data_req_o, data_be_o, data_valid_o});
    endproperty
    a_no_x_out : assert property (p_no_x_out)
        else $error("LSU: X/Z on control outputs");

    a_load_err0  : assert property (@(posedge clk) disable iff(!rst_n) load_err_o  == 1'b0);
    a_store_err0 : assert property (@(posedge clk) disable iff(!rst_n) store_err_o == 1'b0);

    c_idle    : cover property (@(posedge clk) CS==IDLE);
    c_wgnt    : cover property (@(posedge clk) CS==WAIT_GNT);
    c_wrv     : cover property (@(posedge clk) CS==WAIT_RVALID);
    c_wgntmis : cover property (@(posedge clk) CS==WAIT_GNT_MIS);
    c_wrvmis  : cover property (@(posedge clk) CS==WAIT_RVALID_MIS);
    c_mis_seq : cover property (@(posedge clk) disable iff(!rst_n)
                    (CS==WAIT_RVALID_MIS) ##[1:$] (CS==WAIT_RVALID));

endmodule
