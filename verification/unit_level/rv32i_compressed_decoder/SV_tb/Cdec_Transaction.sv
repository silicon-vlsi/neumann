class Cdec_Transaction;
    rand logic [31:0] instr_i;

    logic [31:0] instr_o;
    logic is_compressed_o;
    logic illegal_instr_o;

    constraint c_quadrant
    {
        instr_i[1:0] dist {2'b00 := 30, 2'b01 := 30, 2'b10 := 30, 2'b11 := 10};
    }

    constraint c_fields
    {
        instr_i[11:7] dist {5'd0 := 10, 5'd2 := 10, [5'd1:5'd31] :/ 80};
        instr_i[6:2]  dist {5'd0 := 15, [5'd1:5'd31] :/ 85};
    }

    function void display(string tag="TX");
        $display("[%s] instr_i=%h | instr_o=%h comp=%b ill=%b",
                 tag, instr_i, instr_o, is_compressed_o, illegal_instr_o);
    endfunction

    function Cdec_Transaction do_copy();
        Cdec_Transaction copy;
        copy = new();
        copy.instr_i = this.instr_i;
        copy.instr_o = this.instr_o;
        copy.is_compressed_o = this.is_compressed_o;
        copy.illegal_instr_o = this.illegal_instr_o;
        return copy;
    endfunction
endclass
