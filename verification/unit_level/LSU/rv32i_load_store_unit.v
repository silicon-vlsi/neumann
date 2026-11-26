`include "rv32i_defines.vh"

module rv32i_load_store_unit
(
    input clk,
    input rst_n,
    // output to data memory
    output reg    data_req_o,
    input data_gnt_i,
    input data_rvalid_i,
    input data_err_i,
    output [31:0] data_addr_o,
    output data_we_o,
    output [3:0]  data_be_o,
    output [31:0] data_wdata_o,
    input  [31:0] data_rdata_i,
    // signals from ex stage
    input data_we_ex_i,
    input  [1:0]  data_type_ex_i,
    input  [31:0] data_wdata_ex_i,
    input  [1:0]  data_reg_offset_ex_i,
    input data_sign_ext_ex_i,
    output [31:0] data_rdata_ex_o,
    input data_req_ex_i,
    input  [31:0] adder_result_ex_i,
    output reg    data_misaligned_o,
    output reg [31:0] misaligned_addr_o,
    // exception signals
    output load_err_o,
    output store_err_o,
    // stall signal
    output reg    lsu_update_addr_o,
    output reg    data_valid_o,
    output busy_o
);

    // FSM states
    localparam IDLE            = 3'b000;
    localparam WAIT_GNT_MIS    = 3'b001;
    localparam WAIT_RVALID_MIS = 3'b010;
    localparam WAIT_GNT        = 3'b011;
    localparam WAIT_RVALID     = 3'b100;
    reg [2:0] CS, NS;

    wire [31:0] data_addr_int;
    reg  [1:0]  data_type_q;
    reg  [1:0]  rdata_offset_q;
    reg         data_sign_ext_q;
    reg         data_we_q;
    wire [1:0]  wdata_offset;
    reg  [3:0]  data_be;
    reg  [31:0] data_wdata;
    wire        misaligned_st;
    reg         data_misaligned, data_misaligned_q;
    reg         increase_address;
    reg  [31:0] rdata_q;
    reg  [31:0] data_rdata_ext;
    reg  [31:0] rdata_w_ext;
    reg  [31:0] rdata_h_ext;
    reg  [31:0] rdata_b_ext;

    assign data_addr_int = adder_result_ex_i;
    assign misaligned_st = data_misaligned_q;
    assign load_err_o    = 1'b0;
    assign store_err_o   = 1'b0;

    // output to data interface
    assign data_addr_o   = data_addr_int;
    assign data_wdata_o  = data_wdata;
    assign data_we_o     = data_we_ex_i;
    assign data_be_o     = data_be;

    // output to register file
    assign data_rdata_ex_o = (data_rvalid_i == 1'b1) ? data_rdata_ext : rdata_q;

    assign busy_o = (CS == WAIT_RVALID) | (data_req_o == 1'b1);

    // BE generation
    always @(*) begin
        data_be = 4'b0000;
        case (data_type_ex_i)
            2'b00: begin // word
                if (misaligned_st == 1'b0) begin
                    case (data_addr_int[1:0])
                        2'b00: data_be = 4'b1111;
                        2'b01: data_be = 4'b1110;
                        2'b10: data_be = 4'b1100;
                        2'b11: data_be = 4'b1000;
                    endcase
                end else begin
                    case (data_addr_int[1:0])
                        2'b00: data_be = 4'b0000;
                        2'b01: data_be = 4'b0001;
                        2'b10: data_be = 4'b0011;
                        2'b11: data_be = 4'b0111;
                    endcase
                end
            end
            2'b01: begin // half word
                if (misaligned_st == 1'b0) begin
                    case (data_addr_int[1:0])
                        2'b00: data_be = 4'b0011;
                        2'b01: data_be = 4'b0110;
                        2'b10: data_be = 4'b1100;
                        2'b11: data_be = 4'b1000;
                    endcase
                end else begin
                    data_be = 4'b0001;
                end
            end
            2'b10, 2'b11: begin // byte
                case (data_addr_int[1:0])
                    2'b00: data_be = 4'b0001;
                    2'b01: data_be = 4'b0010;
                    2'b10: data_be = 4'b0100;
                    2'b11: data_be = 4'b1000;
                endcase
            end
        endcase
    end

    // write data alignment
    assign wdata_offset = data_addr_int[1:0] - data_reg_offset_ex_i[1:0];
    always @(*) begin
        case (wdata_offset)
            2'b00: data_wdata = data_wdata_ex_i[31:0];
            2'b01: data_wdata = {data_wdata_ex_i[23:0], data_wdata_ex_i[31:24]};
            2'b10: data_wdata = {data_wdata_ex_i[15:0], data_wdata_ex_i[31:16]};
            2'b11: data_wdata = {data_wdata_ex_i[ 7:0], data_wdata_ex_i[31: 8]};
        endcase
    end

    // FF for rdata alignment and sign-extension
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_type_q     <= 2'b0;
            rdata_offset_q  <= 2'b0;
            data_sign_ext_q <= 1'b0;
            data_we_q       <= 1'b0;
        end else if (data_gnt_i == 1'b1) begin
            data_type_q     <= data_type_ex_i;
            rdata_offset_q  <= data_addr_int[1:0];
            data_sign_ext_q <= data_sign_ext_ex_i;
            data_we_q       <= data_we_ex_i;
        end
    end

    // sign extension for words (misaligned assembly)
    always @(*) begin
        case (rdata_offset_q)
            2'b00: rdata_w_ext = data_rdata_i[31:0];
            2'b01: rdata_w_ext = {data_rdata_i[ 7:0], rdata_q[31:8]};
            2'b10: rdata_w_ext = {data_rdata_i[15:0], rdata_q[31:16]};
            2'b11: rdata_w_ext = {data_rdata_i[23:0], rdata_q[31:24]};
        endcase
    end

    // sign extension for half words
    always @(*) begin
        case (rdata_offset_q)
            2'b00: begin
                if (!data_sign_ext_q) rdata_h_ext = {16'h0000, data_rdata_i[15:0]};
                else                  rdata_h_ext = {{16{data_rdata_i[15]}}, data_rdata_i[15:0]};
            end
            2'b01: begin
                if (!data_sign_ext_q) rdata_h_ext = {16'h0000, data_rdata_i[23:8]};
                else                  rdata_h_ext = {{16{data_rdata_i[23]}}, data_rdata_i[23:8]};
            end
            2'b10: begin
                if (!data_sign_ext_q) rdata_h_ext = {16'h0000, data_rdata_i[31:16]};
                else                  rdata_h_ext = {{16{data_rdata_i[31]}}, data_rdata_i[31:16]};
            end
            2'b11: begin
                if (!data_sign_ext_q) rdata_h_ext = {16'h0000, data_rdata_i[7:0], rdata_q[31:24]};
                else                  rdata_h_ext = {{16{data_rdata_i[7]}}, data_rdata_i[7:0], rdata_q[31:24]};
            end
        endcase
    end

    // sign extension for bytes
    always @(*) begin
        case (rdata_offset_q)
            2'b00: begin
                if (!data_sign_ext_q) rdata_b_ext = {24'h000000, data_rdata_i[7:0]};
                else                  rdata_b_ext = {{24{data_rdata_i[7]}}, data_rdata_i[7:0]};
            end
            2'b01: begin
                if (!data_sign_ext_q) rdata_b_ext = {24'h000000, data_rdata_i[15:8]};
                else                  rdata_b_ext = {{24{data_rdata_i[15]}}, data_rdata_i[15:8]};
            end
            2'b10: begin
                if (!data_sign_ext_q) rdata_b_ext = {24'h000000, data_rdata_i[23:16]};
                else                  rdata_b_ext = {{24{data_rdata_i[23]}}, data_rdata_i[23:16]};
            end
            2'b11: begin
                if (!data_sign_ext_q) rdata_b_ext = {24'h000000, data_rdata_i[31:24]};
                else                  rdata_b_ext = {{24{data_rdata_i[31]}}, data_rdata_i[31:24]};
            end
        endcase
    end

    // select word, half word or byte sign extended version
    always @(*) begin
        case (data_type_q)
            2'b00:       data_rdata_ext = rdata_w_ext;
            2'b01:       data_rdata_ext = rdata_h_ext;
            2'b10,2'b11: data_rdata_ext = rdata_b_ext;
        endcase
    end

    // main sequential block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            CS                <= IDLE;
            rdata_q           <= 32'b0;
            data_misaligned_q <= 1'b0;
            misaligned_addr_o <= 32'b0;
        end else begin
            CS <= NS;
            if (lsu_update_addr_o) begin
                data_misaligned_q <= data_misaligned;
                if (increase_address)
                    misaligned_addr_o <= data_addr_int;
            end
            if (data_rvalid_i && (~data_we_q)) begin
                if ((data_misaligned_q == 1'b1) || (data_misaligned == 1'b1))
                    rdata_q <= data_rdata_i;
                else
                    rdata_q <= data_rdata_ext;
            end
        end
    end

    // FSM
    always @(*) begin
        NS                = CS;
        data_req_o        = 1'b0;
        lsu_update_addr_o = 1'b0;
        data_valid_o      = 1'b0;
        increase_address  = 1'b0;
        data_misaligned_o = 1'b0;

        case (CS)
            IDLE: begin
                if (data_req_ex_i) begin
                    data_req_o = data_req_ex_i;
                    if (data_gnt_i) begin
                        lsu_update_addr_o = 1'b1;
                        increase_address  = data_misaligned;
                        NS = data_misaligned ? WAIT_RVALID_MIS : WAIT_RVALID;
                    end else begin
                        NS = data_misaligned ? WAIT_GNT_MIS : WAIT_GNT;
                    end
                end
            end

            WAIT_GNT_MIS: begin
                data_req_o = 1'b1;
                if (data_gnt_i) begin
                    lsu_update_addr_o = 1'b1;
                    increase_address  = data_misaligned;
                    NS = WAIT_RVALID_MIS;
                end
            end

            WAIT_RVALID_MIS: begin
                increase_address  = 1'b0;
                data_misaligned_o = 1'b1;
                data_req_o        = 1'b0;
                lsu_update_addr_o = data_gnt_i;
                if (data_rvalid_i) begin
                    data_req_o = 1'b1;
                    if (data_gnt_i)
                        NS = WAIT_RVALID;
                    else
                        NS = WAIT_GNT;
                end else begin
                    NS = WAIT_RVALID_MIS;
                end
            end

            WAIT_GNT: begin
                data_misaligned_o = data_misaligned_q;
                data_req_o        = 1'b1;
                if (data_gnt_i) begin
                    lsu_update_addr_o = 1'b1;
                    NS = WAIT_RVALID;
                end
            end

            WAIT_RVALID: begin
                data_req_o = 1'b0;
                if (data_rvalid_i) begin
                    data_valid_o = 1'b1;
                    NS           = IDLE;
                end else begin
                    NS = WAIT_RVALID;
                end
            end

            default: NS = IDLE;
        endcase
    end

    // misaligned access detection
    always @(*) begin
        data_misaligned = 1'b0;
        if ((data_req_ex_i == 1'b1) && (data_misaligned_q == 1'b0)) begin
            case (data_type_ex_i)
                2'b00: begin // word
                    if (data_addr_int[1:0] != 2'b00)
                        data_misaligned = 1'b1;
                end
                2'b01: begin // half word
                    if (data_addr_int[1:0] == 2'b11)
                        data_misaligned = 1'b1;
                end
                default: ;
            endcase
        end
    end
endmodule