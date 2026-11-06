`timescale 1ns/1ps
`include "rv32i_defines.vh"

module lsu_top;
    import lsu_pkg::*;

    parameter int NUM_RAND_TXN = 500;
    parameter int GNT_DELAY    = 1;
    parameter int RVALID_DELAY = 1;
    parameter time CLK_PERIOD  = 10ns;

    logic clk_src = 1'b0;
    logic clk_en  = 1'b1;
    logic clk;

    always #(CLK_PERIOD/2) clk_src = ~clk_src;

    logic en_latched;
    always @(*) if (!clk_src) en_latched = clk_en;
    assign clk = clk_src & en_latched;

    logic rst_n = 1'b0;

    lsu_if vif (.clk(clk), .rst_n(rst_n));

    rv32i_load_store_unit dut (
        .clk                  (clk),
        .rst_n                (rst_n),
        .data_req_o           (vif.data_req_o),
        .data_gnt_i           (vif.data_gnt_i),
        .data_rvalid_i        (vif.data_rvalid_i),
        .data_err_i           (vif.data_err_i),
        .data_addr_o          (vif.data_addr_o),
        .data_we_o            (vif.data_we_o),
        .data_be_o            (vif.data_be_o),
        .data_wdata_o         (vif.data_wdata_o),
        .data_rdata_i         (vif.data_rdata_i),
        .data_we_ex_i         (vif.data_we_ex_i),
        .data_type_ex_i       (vif.data_type_ex_i),
        .data_wdata_ex_i      (vif.data_wdata_ex_i),
        .data_reg_offset_ex_i (vif.data_reg_offset_ex_i),
        .data_sign_ext_ex_i   (vif.data_sign_ext_ex_i),
        .data_rdata_ex_o      (vif.data_rdata_ex_o),
        .data_req_ex_i        (vif.data_req_ex_i),
        .adder_result_ex_i    (vif.adder_result_ex_i),
        .data_misaligned_o    (vif.data_misaligned_o),
        .misaligned_addr_o    (vif.misaligned_addr_o),
        .load_err_o           (vif.load_err_o),
        .store_err_o          (vif.store_err_o),
        .lsu_update_addr_o    (vif.lsu_update_addr_o),
        .data_valid_o         (vif.data_valid_o),
        .busy_o               (vif.busy_o)
    );

    assign vif.dbg_cs = dut.CS;

    bind rv32i_load_store_unit lsu_assertions u_lsu_sva (
        .clk(clk), .rst_n(rst_n),
        .data_req_o(data_req_o), .data_gnt_i(data_gnt_i),
        .data_rvalid_i(data_rvalid_i), .data_err_i(data_err_i),
        .data_addr_o(data_addr_o), .data_we_o(data_we_o),
        .data_be_o(data_be_o), .data_wdata_o(data_wdata_o),
        .data_rdata_i(data_rdata_i),
        .data_we_ex_i(data_we_ex_i), .data_type_ex_i(data_type_ex_i),
        .data_wdata_ex_i(data_wdata_ex_i),
        .data_reg_offset_ex_i(data_reg_offset_ex_i),
        .data_sign_ext_ex_i(data_sign_ext_ex_i),
        .data_rdata_ex_o(data_rdata_ex_o), .data_req_ex_i(data_req_ex_i),
        .adder_result_ex_i(adder_result_ex_i),
        .data_misaligned_o(data_misaligned_o),
        .misaligned_addr_o(misaligned_addr_o),
        .load_err_o(load_err_o), .store_err_o(store_err_o),
        .lsu_update_addr_o(lsu_update_addr_o),
        .data_valid_o(data_valid_o), .busy_o(busy_o),
        .CS(CS)
    );

    initial begin
        $dumpfile("lsu_top.vcd");
        $dumpvars(0, lsu_top);

        clk_en = 1'b1;
        rst_n  = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        begin
            test t;
            t = new(vif, NUM_RAND_TXN, GNT_DELAY, RVALID_DELAY);
            t.run();
        end

        $finish;
    end


    initial begin
        #2000000;
        $display("ERROR: global timeout");
        $finish;
    end

endmodule
