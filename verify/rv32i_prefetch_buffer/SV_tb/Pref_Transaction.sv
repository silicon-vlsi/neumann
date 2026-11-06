class Pref_Transaction;
    rand logic        req_i;
    rand logic        branch_i;
    rand logic [31:0] addr_i;
    rand logic        ready_i;
    rand logic        instr_gnt_i;
    rand int unsigned lat;

    logic        rst_n;
    logic        valid_o;
    logic [31:0] rdata_o;
    logic [31:0] addr_o;
    logic        instr_req_o;
    logic [31:0] instr_addr_o;
    logic [31:0] instr_rdata_i;
    logic        instr_rvalid_i;
    logic        busy_o;

    constraint c_core
    {
        req_i dist {1 := 90, 0 := 10};
        branch_i dist {1 := 5, 0 := 95};
        ready_i dist {1 := 65, 0 := 35};
        branch_i -> req_i;
    }
    constraint c_addr
    {
        addr_i[0] == 1'b0;
        addr_i[31:18] == 14'h0;
    }
    constraint c_mem
    {
        instr_gnt_i dist {1 := 70, 0 := 30};
        lat dist {0 := 60, 1 := 25, [2:3] :/ 15};
    }

    static function logic [31:0] mem_word(logic [31:0] addr);
        logic [31:0] h;
        logic [31:0] w;
        h = {addr[31:2], 2'b00} * 32'h9E37_79B1;
        h = h ^ (h >> 15) ^ 32'h5bd1_e995;
        w = h * 32'h85EB_CA6B;
        w = w ^ (w >> 13);
        if (h[3]) w[1:0]   = 2'b11;
        if (h[7]) w[17:16] = 2'b11;
        return w;
    endfunction

    function void display(string tag="TX");
        $display("[%s] req=%b br=%b addr=%h rdy=%b | v=%b a=%h d=%h | mreq=%b gnt=%b maddr=%h rv=%b busy=%b",
                 tag, req_i, branch_i, addr_i, ready_i, valid_o, addr_o, rdata_o,
                 instr_req_o, instr_gnt_i, instr_addr_o, instr_rvalid_i, busy_o);
    endfunction

    function Pref_Transaction do_copy();
        Pref_Transaction copy;
        copy = new();
        copy.req_i = this.req_i;
        copy.branch_i = this.branch_i;
        copy.addr_i = this.addr_i;
        copy.ready_i = this.ready_i;
        copy.instr_gnt_i = this.instr_gnt_i;
        copy.lat = this.lat;
        copy.rst_n = this.rst_n;
        copy.valid_o = this.valid_o;
        copy.rdata_o = this.rdata_o;
        copy.addr_o = this.addr_o;
        copy.instr_req_o = this.instr_req_o;
        copy.instr_addr_o = this.instr_addr_o;
        copy.instr_rdata_i = this.instr_rdata_i;
        copy.instr_rvalid_i = this.instr_rvalid_i;
        copy.busy_o = this.busy_o;
        return copy;
    endfunction
endclass
