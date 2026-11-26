class Reg_driver #(parameter RV32E = 0, parameter DATA_WIDTH = 32);
    typedef Reg_Transaction #(RV32E, DATA_WIDTH) tx_t;
    virtual Reg_interface #(DATA_WIDTH).DRV vif;
    mailbox #(tx_t) gen2drv;
    int drv_count=0;

    function new(mailbox #(tx_t) gen2drv, virtual Reg_interface #(DATA_WIDTH).DRV vif);
        this.vif=vif;
        this.gen2drv=gen2drv;
    endfunction

    task automatic reset(int cycles=5);
        vif.drv_cb.rst_n     <= 1'b0;
        vif.drv_cb.test_en_i <= 1'b0;
        vif.drv_cb.we_a_i    <= 1'b0;
        vif.drv_cb.raddr_a_i <= '0;
        vif.drv_cb.raddr_b_i <= '0;
        vif.drv_cb.waddr_a_i <= '0;
        vif.drv_cb.wdata_a_i <= '0;
        repeat(cycles) @(vif.drv_cb);
        vif.drv_cb.rst_n     <= 1'b1;
        @(vif.drv_cb);
    endtask

    task run();
        tx_t tx;
        forever begin
            gen2drv.get(tx);
            @(vif.drv_cb);
            vif.drv_cb.rst_n     <= tx.rst_n;
            vif.drv_cb.test_en_i <= tx.test_en_i;
            vif.drv_cb.raddr_a_i <= tx.raddr_a_i;
            vif.drv_cb.raddr_b_i <= tx.raddr_b_i;
            vif.drv_cb.waddr_a_i <= tx.waddr_a_i;
            vif.drv_cb.wdata_a_i <= tx.wdata_a_i;
            vif.drv_cb.we_a_i    <= tx.we_a_i;
            tx.display("DRV");
            drv_count++;
        end
    endtask
endclass