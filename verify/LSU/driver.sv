class driver;

    virtual lsu_if vif;
    mailbox #(transaction) gen2drv;
    int drv_count = 0;

    function new(virtual lsu_if vif, mailbox #(transaction) gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    task automatic idle();
        vif.drv_cb.data_req_ex_i        <= 1'b0;
        vif.drv_cb.data_we_ex_i         <= 1'b0;
        vif.drv_cb.data_type_ex_i       <= 2'b00;
        vif.drv_cb.data_wdata_ex_i      <= 32'h0;
        vif.drv_cb.data_reg_offset_ex_i <= 2'b00;
        vif.drv_cb.data_sign_ext_ex_i   <= 1'b0;
        vif.drv_cb.adder_result_ex_i    <= 32'h0;
    endtask

    task run();
        transaction tr;
        wait (vif.rst_n === 1'b1);
        @(vif.drv_cb);
        idle();

        forever begin
            gen2drv.get(tr);

            @(vif.drv_cb);
            vif.drv_cb.data_req_ex_i        <= 1'b1;
            vif.drv_cb.data_we_ex_i         <= tr.we;
            vif.drv_cb.data_type_ex_i       <= tr.dtype;
            vif.drv_cb.data_wdata_ex_i      <= tr.wdata;
            vif.drv_cb.data_reg_offset_ex_i <= tr.reg_off;
            vif.drv_cb.data_sign_ext_ex_i   <= tr.sext;
            vif.drv_cb.adder_result_ex_i    <= tr.addr;

            @(vif.drv_cb);
            while (vif.drv_cb.data_gnt_i !== 1'b1) @(vif.drv_cb);

            vif.drv_cb.data_req_ex_i <= 1'b0;

            while (vif.drv_cb.data_valid_o !== 1'b1) @(vif.drv_cb);

            idle();
            drv_count++;
            @(vif.drv_cb);
        end
    endtask

endclass
