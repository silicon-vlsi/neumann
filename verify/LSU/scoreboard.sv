class scoreboard;

    mailbox #(transaction) mon2scb;
    byte unsigned mem [0:4095];
    int pass_count = 0;
    int fail_count = 0;

    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
        foreach (mem[i]) mem[i] = i[7:0];
    endfunction

    function bit [3:0] pred_be(bit [1:0] dtype, bit [31:0] addr);
        bit [1:0] o = addr[1:0];
        case (dtype)
            2'b00: case (o) 2'b00:pred_be=4'b1111; 2'b01:pred_be=4'b1110;
                            2'b10:pred_be=4'b1100; 2'b11:pred_be=4'b1000; endcase
            2'b01: case (o) 2'b00:pred_be=4'b0011; 2'b01:pred_be=4'b0110;
                            2'b10:pred_be=4'b1100; 2'b11:pred_be=4'b1000; endcase
            default: case (o) 2'b00:pred_be=4'b0001; 2'b01:pred_be=4'b0010;
                              2'b10:pred_be=4'b0100; 2'b11:pred_be=4'b1000; endcase
        endcase
    endfunction

    function bit [31:0] rd_bytes(bit [31:0] addr, int n);
        rd_bytes = 32'h0;
        for (int i = 0; i < n; i++)
            rd_bytes[8*i +: 8] = mem[(addr + i) & 12'hFFF];
    endfunction

    function bit [31:0] pred_load(bit [1:0] dtype, bit [31:0] addr, bit sext);
        bit [31:0] raw;
        case (dtype)
            2'b00: pred_load = rd_bytes(addr, 4);
            2'b01: begin
                raw = rd_bytes(addr, 2);
                pred_load = sext ? {{16{raw[15]}}, raw[15:0]}
                                 : {16'h0, raw[15:0]};
            end
            default: begin
                raw = rd_bytes(addr, 1);
                pred_load = sext ? {{24{raw[7]}}, raw[7:0]}
                                 : {24'h0, raw[7:0]};
            end
        endcase
    endfunction

    task store_mirror(bit [1:0] dtype, bit [31:0] addr, bit [31:0] wd);
        int n = (dtype==2'b00) ? 4 : (dtype==2'b01) ? 2 : 1;
        for (int i = 0; i < n; i++)
            mem[(addr + i) & 12'hFFF] = wd[8*i +: 8];
    endtask

    task run();
        transaction tr;
        forever begin
            mon2scb.get(tr);

            if (tr.we) begin
                store_mirror(tr.dtype, tr.addr, tr.wdata);
                pass_count++;
            end else begin
                tr.exp_rdata = pred_load(tr.dtype, tr.addr, tr.sext);
                if (tr.rdata_ex !== tr.exp_rdata) begin
                    fail_count++;
                    $display("[SCB][FAIL-LD] type=%0d addr=%08h sext=%b got=%08h exp=%08h",
                             tr.dtype, tr.addr, tr.sext, tr.rdata_ex, tr.exp_rdata);
                end else pass_count++;
            end

            if (!tr.misaligned) begin
                tr.exp_be = pred_be(tr.dtype, tr.addr);
                if (tr.be !== tr.exp_be) begin
                    fail_count++;
                    $display("[SCB][FAIL-BE] type=%0d addr=%08h got=%b exp=%b",
                             tr.dtype, tr.addr, tr.be, tr.exp_be);
                end
            end
        end
    endtask

    function void report();
        $display("========== SCOREBOARD ==========");
        $display(" PASS=%0d  FAIL=%0d", pass_count, fail_count);
        $display(" RESULT: %s", (fail_count==0)?"*** PASS ***":"*** FAIL ***");
        $display("================================");
    endfunction

endclass
