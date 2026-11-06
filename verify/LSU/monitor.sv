class monitor;

    virtual lsu_if vif;
    mailbox #(transaction) mon2scb;
    mailbox #(transaction) mon2cov;
    int mon_count = 0;

    function new(virtual lsu_if vif,
                 mailbox #(transaction) mon2scb,
                 mailbox #(transaction) mon2cov);
        this.vif     = vif;
        this.mon2scb = mon2scb;
        this.mon2cov = mon2cov;
    endfunction

    task run();
        transaction tr;
        bit [31:0] q_addr, q_wdata;
        bit [1:0]  q_type;
        bit        q_we, q_sext;
        bit [3:0]  q_be;
        bit        q_mis;

        wait (vif.rst_n === 1'b1);

        forever begin
            @(vif.mon_cb);

            if (vif.mon_cb.data_gnt_i === 1'b1) begin
                q_addr  = vif.mon_cb.adder_result_ex_i;
                q_type  = vif.mon_cb.data_type_ex_i;
                q_we    = vif.mon_cb.data_we_ex_i;
                q_sext  = vif.mon_cb.data_sign_ext_ex_i;
                q_wdata = vif.mon_cb.data_wdata_ex_i;
                q_be    = vif.mon_cb.data_be_o;
                q_mis   = vif.mon_cb.data_misaligned_o;
            end

            if (vif.mon_cb.data_valid_o === 1'b1) begin
                tr = new();
                tr.addr       = q_addr;
                tr.dtype      = q_type;
                tr.we         = q_we;
                tr.sext       = q_sext;
                tr.wdata      = q_wdata;
                tr.be         = q_be;
                tr.misaligned = q_mis;
                tr.rdata_ex   = vif.mon_cb.data_rdata_ex_o;

                mon2scb.put(tr.copy());
                mon2cov.put(tr.copy());
                mon_count++;
            end
        end
    endtask

endclass
