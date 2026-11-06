class mem_slave;

    virtual lsu_if vif;

    int gnt_delay    = 0;
    int rvalid_delay = 1;

    byte unsigned mem [0:4095];

    function new(virtual lsu_if vif);
        this.vif = vif;
        foreach (mem[i]) mem[i] = i[7:0];
    endfunction

    function bit [31:0] read_word(bit [31:0] a);
        bit [11:0] base = {a[11:2], 2'b00};
        read_word = {mem[base+3], mem[base+2], mem[base+1], mem[base+0]};
    endfunction

    task write_word(bit [31:0] a, bit [31:0] d, bit [3:0] be);
        bit [11:0] base = {a[11:2], 2'b00};
        if (be[0]) mem[base+0] = d[7:0];
        if (be[1]) mem[base+1] = d[15:8];
        if (be[2]) mem[base+2] = d[23:16];
        if (be[3]) mem[base+3] = d[31:24];
    endtask

    task run();
        int gcnt;
        wait (vif.rst_n === 1'b1);
        vif.mem_cb.data_gnt_i    <= 1'b0;
        vif.mem_cb.data_rvalid_i <= 1'b0;
        vif.mem_cb.data_err_i    <= 1'b0;
        vif.mem_cb.data_rdata_i  <= 32'h0;
        gcnt = 0;

        forever begin
            @(vif.mem_cb);
            vif.mem_cb.data_gnt_i    <= 1'b0;
            vif.mem_cb.data_rvalid_i <= 1'b0;

            if (vif.mem_cb.data_req_o === 1'b1) begin
                if (gcnt >= gnt_delay) begin
                    vif.mem_cb.data_gnt_i <= 1'b1;
                    gcnt = 0;

                    begin
                        bit [31:0] a  = vif.mem_cb.data_addr_o;
                        bit        we = vif.mem_cb.data_we_o;
                        bit [3:0]  be = vif.mem_cb.data_be_o;
                        bit [31:0] wd = vif.mem_cb.data_wdata_o;

                        if (we) write_word(a, wd, be);

                        repeat (rvalid_delay) @(vif.mem_cb);
                        vif.mem_cb.data_rvalid_i <= 1'b1;
                        vif.mem_cb.data_rdata_i  <= read_word(a);
                        @(vif.mem_cb);
                        vif.mem_cb.data_rvalid_i <= 1'b0;
                    end
                end else begin
                    gcnt++;
                end
            end else begin
                gcnt = 0;
            end
        end
    endtask

endclass
