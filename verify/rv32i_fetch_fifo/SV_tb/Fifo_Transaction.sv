class Fifo_Transaction;
    rand logic        clear_i;
    rand logic [31:0] target;
    rand logic        push;
    rand logic        out_ready_i;

    logic        rst_n;
    logic [31:0] in_addr_i;
    logic [31:0] in_rdata_i;
    logic        in_valid_i;
    logic        in_ready_o;
    logic        out_valid_o;
    logic [31:0] out_rdata_o;
    logic [31:0] out_addr_o;
    logic        out_valid_stored_o;

    constraint c_clear
    {
        clear_i dist {1 := 4, 0 := 96};
    }
    constraint c_target
    {
        target[0] == 1'b0;
        target[31:16] == 16'h0;
        target[1] dist {1 := 50, 0 := 50};
    }
    constraint c_flow
    {
        push dist {1 := 70, 0 := 30};
        out_ready_i dist {1 := 60, 0 := 40};
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
        $display("[%s] clr=%b in_v=%b in_a=%h in_d=%h in_rdy=%b | out_v=%b out_rdy=%b out_a=%h out_d=%h st=%b",
                 tag, clear_i, in_valid_i, in_addr_i, in_rdata_i, in_ready_o,
                 out_valid_o, out_ready_i, out_addr_o, out_rdata_o, out_valid_stored_o);
    endfunction

    function Fifo_Transaction do_copy();
        Fifo_Transaction copy;
        copy = new();
        copy.clear_i = this.clear_i;
        copy.target = this.target;
        copy.push = this.push;
        copy.out_ready_i = this.out_ready_i;
        copy.rst_n = this.rst_n;
        copy.in_addr_i = this.in_addr_i;
        copy.in_rdata_i = this.in_rdata_i;
        copy.in_valid_i = this.in_valid_i;
        copy.in_ready_o = this.in_ready_o;
        copy.out_valid_o = this.out_valid_o;
        copy.out_rdata_o = this.out_rdata_o;
        copy.out_addr_o = this.out_addr_o;
        copy.out_valid_stored_o = this.out_valid_stored_o;
        return copy;
    endfunction
endclass
