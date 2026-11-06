class Reg_Transaction #(parameter RV32E = 0, parameter DATA_WIDTH = 32);
    localparam ADDR_WIDTH = RV32E ? 4 : 5;
    localparam NUM_WORDS  = 2**ADDR_WIDTH;
    rand logic rst_n;
    rand logic test_en_i;
    rand logic [4:0] raddr_a_i;
    rand logic [4:0] raddr_b_i;
    rand logic [4:0] waddr_a_i;
    rand logic [DATA_WIDTH-1:0] wdata_a_i;
    rand logic we_a_i;
    logic [DATA_WIDTH-1:0] rdata_b_o;
    logic [DATA_WIDTH-1:0] rdata_a_o;

    constraint c_addr_range
    {
        raddr_a_i < NUM_WORDS;
        raddr_b_i < NUM_WORDS;
        waddr_a_i < NUM_WORDS;
    }

    constraint c_x0
    {
        waddr_a_i dist {0:=10,[1:NUM_WORDS-1]:/90};
        raddr_a_i dist {0:=10,[1:NUM_WORDS-1]:/90};
        raddr_b_i dist {0:=10,[1:NUM_WORDS-1]:/90};
    }

    constraint c_wdata
    {
        wdata_a_i dist {{DATA_WIDTH{1'b0}}:=5, {DATA_WIDTH{1'b1}}:=5, [1:{DATA_WIDTH{1'b1}}-1]:/90};
    }
    constraint c_ctrl
    {
        we_a_i dist {1:=60,0:=40};
        test_en_i dist {1:=5, 0:=95};
    }

    function void display(string tag="TX");
         $display("[%s] RV32E=%0d DW=%0d | we=%b ten=%b waddr=%0d wdata=%h raddr_a=%0d raddr_b=%0d | rdata_a=%h rdata_b=%h",
                 tag, RV32E, DATA_WIDTH, we_a_i, test_en_i, waddr_a_i, wdata_a_i,
                 raddr_a_i, raddr_b_i, rdata_a_o, rdata_b_o);
    endfunction

    function Reg_Transaction #(RV32E, DATA_WIDTH) do_copy();
        Reg_Transaction #(RV32E, DATA_WIDTH) copy;
        copy = new();
        copy.rst_n=this.rst_n;
        copy.test_en_i=this.test_en_i;
        copy.raddr_a_i=this.raddr_a_i;
        copy.raddr_b_i=this.raddr_b_i;
        copy.waddr_a_i=this.waddr_a_i;
        copy.wdata_a_i=this.wdata_a_i;
        copy.we_a_i=this.we_a_i;
        copy.rdata_a_o=this.rdata_a_o;
        copy.rdata_b_o=this.rdata_b_o;
        return copy;
    endfunction

endclass