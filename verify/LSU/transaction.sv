class transaction;

    rand bit        we;
    rand bit [1:0]  dtype;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    rand bit        sext;
    rand bit [1:0]  reg_off;

    bit [31:0] rdata_ex;
    bit [3:0]  be;
    bit        misaligned;

    bit [31:0] exp_rdata;
    bit [3:0]  exp_be;

    constraint c_addr { addr[31:12] == 20'h0; }
    constraint c_type { dtype inside {2'b00, 2'b01, 2'b10, 2'b11}; }
    constraint c_align {
        addr[1:0] dist { 2'b00:/40, 2'b01:/20, 2'b10:/20, 2'b11:/20 };
    }
    constraint c_regoff { reg_off == 2'b00; }

    function transaction copy();
        copy = new();
        copy.we=we; copy.dtype=dtype; copy.addr=addr; copy.wdata=wdata;
        copy.sext=sext; copy.reg_off=reg_off;
        copy.rdata_ex=rdata_ex; copy.be=be; copy.misaligned=misaligned;
        copy.exp_rdata=exp_rdata; copy.exp_be=exp_be;
    endfunction

    function void print(string tag="");
        $display("[%s] %s type=%0d addr=%08h wd=%08h sext=%b | be=%b mis=%b rd=%08h",
                 tag, we?"ST":"LD", dtype, addr, wdata, sext,
                 be, misaligned, rdata_ex);
    endfunction

endclass
