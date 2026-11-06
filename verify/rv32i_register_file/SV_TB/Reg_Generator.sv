class Reg_Generator #(parameter RV32E = 0, parameter DATA_WIDTH = 32);
    typedef Reg_Transaction #(RV32E, DATA_WIDTH) tx_t;
    localparam ADDR_WIDTH = RV32E ? 4 : 5;
    localparam NUM_WORDS  = 2**ADDR_WIDTH;

    mailbox #(tx_t) gen2drv;
    int num_tx;
    int gen_count=0;
    bit done=0;
    string test_type="random";

    function new(mailbox #(tx_t) gen2drv, int num_tx=1000, string test_type="random");
        this.gen2drv=gen2drv;
        this.num_tx=num_tx;
        this.test_type=test_type;
    endfunction

    task run();
        $display("[GEN] Starting test '%s' (num_tx=%0d, NUM_WORDS=%0d)", test_type, num_tx, NUM_WORDS);
        case(test_type)
            "random":     random_test();
            "write":      write_test();
            "read":       read_test();
            "write_read": write_read_test();
            "x0":         x0_test();
            "corner":     corner_data_test();
            "same_addr":  same_addr_test();
            "test_en":    test_en_test();
            "all":        all_test();
            default: begin
                $error("[GEN] Unknown test_type '%s', falling back to random", test_type);
                random_test();
            end
        endcase
        done=1;
        $display("[GEN] Done: %0d transactions generated", gen_count);
    endtask

    task send(tx_t tx);
        gen2drv.put(tx);
        gen_count++;
    endtask

    task random_test();
        tx_t tx;
        repeat(num_tx) begin
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; })
                $fatal(1, "[GEN] random_test: randomize failed");
            send(tx);
        end
    endtask

    task write_test();
        tx_t tx;
        for(int n=0; n<num_tx; n++) begin
            int addr=n%NUM_WORDS;
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==1; waddr_a_i==addr; })
                $fatal(1, "[GEN] write_test: randomize failed");
            send(tx);
        end
    endtask

    task read_test();
        tx_t tx;
        fill_all();
        for(int n=0; n<num_tx; n++) begin
            int addr_a=n%NUM_WORDS;
            int addr_b=(NUM_WORDS-1)-(n%NUM_WORDS);
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==0;
                                      raddr_a_i==addr_a; raddr_b_i==addr_b; })
                $fatal(1, "[GEN] read_test: randomize failed");
            send(tx);
        end
    endtask

    task write_read_test();
        tx_t tx;
        for(int n=0; n<num_tx/2; n++) begin
            int addr=n%NUM_WORDS;
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==1; waddr_a_i==addr; })
                $fatal(1, "[GEN] write_read_test: write randomize failed");
            send(tx);
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==0;
                                      raddr_a_i==addr; raddr_b_i==addr; })
                $fatal(1, "[GEN] write_read_test: read randomize failed");
            send(tx);
        end
    endtask

    task x0_test();
        tx_t tx;
        for(int n=0; n<num_tx/2; n++) begin
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==1;
                                      waddr_a_i==0; wdata_a_i!=0; })
                $fatal(1, "[GEN] x0_test: write randomize failed");
            send(tx);
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==0;
                                      raddr_a_i==0; raddr_b_i==0; })
                $fatal(1, "[GEN] x0_test: read randomize failed");
            send(tx);
        end
    endtask

    task corner_data_test();
        tx_t tx;
        logic [DATA_WIDTH-1:0] patterns[$];
        patterns.push_back({DATA_WIDTH{1'b0}});
        patterns.push_back({DATA_WIDTH{1'b1}});
        patterns.push_back({(DATA_WIDTH/2){2'b01}});
        patterns.push_back({(DATA_WIDTH/2){2'b10}});
        for(int b=0; b<DATA_WIDTH; b++)
            patterns.push_back({{(DATA_WIDTH-1){1'b0}},1'b1} << b);
        for(int b=0; b<DATA_WIDTH; b++)
            patterns.push_back(~({{(DATA_WIDTH-1){1'b0}},1'b1} << b));

        foreach(patterns[p]) 
        begin
            for(int addr=1; addr<NUM_WORDS; addr++) begin
                logic [DATA_WIDTH-1:0] pat=patterns[p];
                tx=new();
                if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==1;
                                          waddr_a_i==addr; wdata_a_i==pat; })
                    $fatal(1, "[GEN] corner_data_test: write randomize failed");
                send(tx);
                tx=new();
                if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==0;
                                          raddr_a_i==addr; raddr_b_i==addr; })
                    $fatal(1, "[GEN] corner_data_test: read randomize failed");
                send(tx);
            end
        end
    endtask

    task same_addr_test();
        tx_t tx;
        repeat(num_tx) 
        begin
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==1;
                                      raddr_a_i==waddr_a_i; raddr_b_i==waddr_a_i; })
                $fatal(1, "[GEN] same_addr_test: randomize failed");
            send(tx);
        end
    endtask

    task test_en_test();
        tx_t tx;
        repeat(num_tx) 
        begin
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i dist {1:=50, 0:=50}; })
                $fatal(1, "[GEN] test_en_test: randomize failed");
            send(tx);
        end
    endtask

    task all_test();
        random_test();
        write_test();
        read_test();
        write_read_test();
        x0_test();
        corner_data_test();
        same_addr_test();
        test_en_test();
        random_test();
    endtask

    task fill_all();
        tx_t tx;
        for(int addr=0; addr<NUM_WORDS; addr++) 
        begin
            tx=new();
            if(!tx.randomize() with { rst_n==1; test_en_i==0; we_a_i==1; waddr_a_i==addr; })
                $fatal(1, "[GEN] fill_all: randomize failed");
            send(tx);
        end
    endtask

endclass
