interface lsu_if (input logic clk, input logic rst_n);

    logic        data_req_o;
    logic        data_gnt_i;
    logic        data_rvalid_i;
    logic        data_err_i;
    logic [31:0] data_addr_o;
    logic        data_we_o;
    logic [3:0]  data_be_o;
    logic [31:0] data_wdata_o;
    logic [31:0] data_rdata_i;

    logic        data_we_ex_i;
    logic [1:0]  data_type_ex_i;
    logic [31:0] data_wdata_ex_i;
    logic [1:0]  data_reg_offset_ex_i;
    logic        data_sign_ext_ex_i;
    logic [31:0] data_rdata_ex_o;
    logic        data_req_ex_i;
    logic [31:0] adder_result_ex_i;

    logic        data_misaligned_o;
    logic [31:0] misaligned_addr_o;
    logic        load_err_o;
    logic        store_err_o;
    logic        lsu_update_addr_o;
    logic        data_valid_o;
    logic        busy_o;

    logic [2:0]  dbg_cs;

    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        output data_req_ex_i, data_we_ex_i, data_type_ex_i,
               data_wdata_ex_i, data_reg_offset_ex_i,
               data_sign_ext_ex_i, adder_result_ex_i;
        input  data_gnt_i, data_valid_o, data_misaligned_o;
    endclocking

    clocking mem_cb @(posedge clk);
        default input #1step output #1;
        output data_gnt_i, data_rvalid_i, data_rdata_i, data_err_i;
        input  data_req_o, data_addr_o, data_we_o, data_be_o, data_wdata_o;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input data_req_o, data_addr_o, data_we_o, data_be_o, data_wdata_o,
              data_rdata_i, data_gnt_i, data_rvalid_i,
              data_req_ex_i, data_we_ex_i, data_type_ex_i, data_wdata_ex_i,
              data_reg_offset_ex_i, data_sign_ext_ex_i, adder_result_ex_i,
              data_rdata_ex_o, data_misaligned_o, misaligned_addr_o,
              data_valid_o, lsu_update_addr_o, busy_o;
    endclocking

    modport DRV (clocking drv_cb, input clk, input rst_n);
    modport MEM (clocking mem_cb, input clk, input rst_n);
    modport MON (clocking mon_cb, input clk, input rst_n);

endinterface
