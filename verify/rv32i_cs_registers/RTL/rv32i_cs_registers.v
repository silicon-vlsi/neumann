`include "rv32i_defines.vh"
module rv32i_cs_registers
#(
    // Number of built-in performance counters (1..11).
    //   2  : cycles + instructions (default, tapeout configuration)
    //   11 : full PULP-style event set (profiling configuration)
    parameter N_PERF_CNT = 2,
    parameter N_EXT_CNT  = 0
)
(
    input clk,
    input rst_n,
    input  [3:0]  core_id_i,
    input  [5:0]  cluster_id_i,
    input  [23:0] boot_addr_i,
    // CSR interface
    input  csr_access_i,
    input  [11:0] csr_addr_i,
    input  [31:0] csr_wdata_i,
    input  [1:0]  csr_op_i,
    output reg [31:0] csr_rdata_o,
    // Interrupts
    output m_irq_enable_o,
    output [31:0] mepc_o,
    input  [31:0] pc_if_i,
    input  [31:0] pc_id_i,
    input  csr_save_if_i,
    input  csr_save_id_i,
    input  csr_restore_mret_i,
    input  [5:0] csr_cause_i,
    input  csr_save_cause_i,
    // Performance counter inputs
    input if_valid_i,
    input id_valid_i,
    input is_compressed_i,
    input is_decoding_i,
    input imiss_i,
    input pc_set_i,
    input jump_i,
    input branch_i,
    input branch_taken_i,
    input mem_load_i,
    input mem_store_i,
    input  [N_EXT_CNT-1:0] ext_counters_i
);
    localparam N_PERF_COUNTERS = N_PERF_CNT + N_EXT_CNT;
    localparam N_PERF_REGS     = N_PERF_COUNTERS;
    // mstatus fields (replaces SV struct)
    reg mstatus_mie_q,  mstatus_mie_n;
    reg mstatus_mpie_q, mstatus_mpie_n;
    // mpp is always PRIV_LVL_M (2'b11), hardwired
    reg [31:0] mepc_q, mepc_n;
    reg [5:0]  mcause_q, mcause_n;
    // CSR operation
    reg [31:0] csr_wdata_int;
    reg [31:0] csr_rdata_int;
    reg csr_we_int;
    // Performance counters
    reg  id_valid_q;
    wire [N_PERF_COUNTERS-1:0]  PCCR_in;
    reg  [N_PERF_COUNTERS-1:0]  PCCR_inc, PCCR_inc_q;
    reg  [31:0] PCCR_q [0:N_PERF_REGS-1];
    reg  [31:0] PCCR_n [0:N_PERF_REGS-1];
    reg  [1:0] PCMR_n, PCMR_q;
    reg  [N_PERF_COUNTERS-1:0] PCER_n, PCER_q;
    reg  [31:0] perf_rdata;
    reg  [4:0] pccr_index;
    reg  pccr_all_sel;
    reg  is_pccr;
    reg  is_pcer;
    reg  is_pcmr;
    // outputs
    assign m_irq_enable_o = mstatus_mie_q;
    assign mepc_o = mepc_q;
    // CSR read logic
    always @(*) begin
        csr_rdata_int = 32'b0;
        case (csr_addr_i)
            12'h300: csr_rdata_int = {19'b0, `PRIV_LVL_M, 3'b0, mstatus_mpie_q, 3'b0, mstatus_mie_q, 3'b0};
            12'h305: csr_rdata_int = {boot_addr_i, 8'h0};
            12'h341: csr_rdata_int = mepc_q;
            12'h342: csr_rdata_int = {mcause_q[5], 26'b0, mcause_q[4:0]};
            12'hF14: csr_rdata_int = {21'b0, cluster_id_i[5:0], 1'b0, core_id_i[3:0]};
            default: ;
        endcase
    end
    // CSR write logic
    always @(*) begin
        mepc_n = mepc_q;
        mstatus_mie_n  = mstatus_mie_q;
        mstatus_mpie_n = mstatus_mpie_q;
        mcause_n = mcause_q;
        case (csr_addr_i)
            12'h300: 
            if (csr_we_int) 
            begin
                mstatus_mie_n  = csr_wdata_int[3];
                mstatus_mpie_n = csr_wdata_int[7];
            end
            12'h341: if (csr_we_int) mepc_n = csr_wdata_int;
            12'h342: if (csr_we_int) mcause_n = {csr_wdata_int[31], csr_wdata_int[4:0]};
            default: ;
        endcase
        // exception controller gets priority
        if (csr_save_cause_i) 
        begin
            if (csr_save_if_i)
                mepc_n = pc_if_i;
            else if (csr_save_id_i)
                mepc_n = pc_id_i;
            mstatus_mpie_n = mstatus_mie_q;
            mstatus_mie_n  = 1'b0;
            mcause_n       = csr_cause_i;
        end 
        else if (csr_restore_mret_i) 
        begin
            mstatus_mie_n  = mstatus_mpie_q;
            mstatus_mpie_n = 1'b1;
        end
    end
    // CSR operation logic
    always @(*) 
    begin
        csr_wdata_int = csr_wdata_i;
        csr_we_int    = 1'b1;
        case (csr_op_i)
            `CSR_OP_WRITE: csr_wdata_int = csr_wdata_i;
            `CSR_OP_SET:   csr_wdata_int = csr_wdata_i | csr_rdata_o;
            `CSR_OP_CLEAR: csr_wdata_int = (~csr_wdata_i) & csr_rdata_o;
            `CSR_OP_NONE: 
            begin
                csr_wdata_int = csr_wdata_i;
                csr_we_int    = 1'b0;
            end
        endcase
    end
    // output mux
    always @(*) 
    begin
        csr_rdata_o = csr_rdata_int;
        if (is_pccr || is_pcer || is_pcmr)
            csr_rdata_o = perf_rdata;
    end

    // CSR registers
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            mstatus_mie_q  <= 1'b0;
            mstatus_mpie_q <= 1'b0;
            mepc_q         <= 32'b0;
            mcause_q       <= 6'b0;
        end 
        else 
        begin
            mstatus_mie_q  <= mstatus_mie_n;
            mstatus_mpie_q <= mstatus_mpie_n;
            mepc_q         <= mepc_n;
            mcause_q       <= mcause_n;
        end
    end
    // =========================================================
    // Performance Counters
    // =========================================================
    // Full event list. Only the first N_PERF_CNT entries get a counter;
    // the rest are left unconnected and removed by synthesis.
    wire [10:0] perf_events;
    assign perf_events[0]  = 1'b1;                                      // cycles
    assign perf_events[1]  = id_valid_i & is_decoding_i;                // instructions issued
    assign perf_events[2]  = 1'b0;                                      // reserved
    assign perf_events[3]  = 1'b0;                                      // reserved
    assign perf_events[4]  = imiss_i & (~pc_set_i);                     // instruction fetch wait cycles
    assign perf_events[5]  = mem_load_i;                                // loads
    assign perf_events[6]  = mem_store_i;                               // stores
    assign perf_events[7]  = jump_i;                                    // jumps
    assign perf_events[8]  = branch_i;                                  // branches
    assign perf_events[9]  = branch_taken_i;                            // taken branches
    assign perf_events[10] = id_valid_i & is_decoding_i & is_compressed_i; // compressed instructions

    assign PCCR_in[N_PERF_CNT-1:0] = perf_events[N_PERF_CNT-1:0];

    genvar gi;
    generate
        for (gi = 0; gi < N_EXT_CNT; gi = gi + 1) 
        begin 
            assign PCCR_in[N_PERF_COUNTERS - N_EXT_CNT + gi] = ext_counters_i[gi];
        end
    endgenerate
    // perf counter address decoder
    always @(*) 
    begin
        is_pccr      = 1'b0;
        is_pcmr      = 1'b0;
        is_pcer      = 1'b0;
        pccr_all_sel = 1'b0;
        pccr_index   = 5'b0;
        perf_rdata   = 32'b0;

        if (csr_access_i) 
        begin
            case (csr_addr_i)
                12'h7A0: 
                begin
                    is_pcer = 1'b1;
                    perf_rdata[N_PERF_COUNTERS-1:0] = PCER_q;
                end
                12'h7A1: 
                begin
                    is_pcmr = 1'b1;
                    perf_rdata[1:0] = PCMR_q;
                end
                12'h79F: 
                begin
                    is_pccr = 1'b1;
                    pccr_all_sel = 1'b1;
                end
                default: ;
            endcase
            if (csr_addr_i[11:5] == 7'b0111100) 
            begin
                is_pccr    = 1'b1;
                pccr_index = csr_addr_i[4:0];
                // counters above N_PERF_REGS do not exist, read them as 0 instead of X
                perf_rdata = (csr_addr_i[4:0] < N_PERF_REGS) ? PCCR_q[csr_addr_i[4:0]] : 32'b0;
            end
        end
    end
    // perf counter update logic
    integer pi;
    always @(*) 
    begin
        for (pi = 0; pi < N_PERF_COUNTERS; pi = pi + 1) 
        begin
            PCCR_inc[pi] = PCCR_in[pi] & PCER_q[pi] & PCMR_q[0];
            PCCR_n[pi]   = PCCR_q[pi];
            if ((PCCR_inc_q[pi] == 1'b1) && ((PCCR_q[pi] != 32'hFFFFFFFF) || (PCMR_q[1] == 1'b0)))
                PCCR_n[pi] = PCCR_q[pi] + 32'd1;
            if (is_pccr == 1'b1 && (pccr_all_sel == 1'b1 || pccr_index == pi)) 
            begin
                case (csr_op_i)
                    `CSR_OP_NONE:  ;
                    `CSR_OP_WRITE: PCCR_n[pi] = csr_wdata_i;
                    `CSR_OP_SET:   PCCR_n[pi] = csr_wdata_i | PCCR_q[pi];
                    `CSR_OP_CLEAR: PCCR_n[pi] = PCCR_q[pi] & ~csr_wdata_i;
                endcase
            end
        end
    end
    // PCMR and PCER update
    always @(*) 
    begin
        PCMR_n = PCMR_q;
        PCER_n = PCER_q;
        if (is_pcmr) 
        begin
            case (csr_op_i)
                `CSR_OP_NONE:  ;
                `CSR_OP_WRITE: PCMR_n = csr_wdata_i[1:0];
                `CSR_OP_SET:   PCMR_n = csr_wdata_i[1:0] | PCMR_q;
                `CSR_OP_CLEAR: PCMR_n = PCMR_q & ~csr_wdata_i[1:0];
            endcase
        end
        if (is_pcer) 
        begin
            case (csr_op_i)
                `CSR_OP_NONE:  ;
                `CSR_OP_WRITE: PCER_n = csr_wdata_i[N_PERF_COUNTERS-1:0];
                `CSR_OP_SET:   PCER_n = csr_wdata_i[N_PERF_COUNTERS-1:0] | PCER_q;
                `CSR_OP_CLEAR: PCER_n = PCER_q & ~csr_wdata_i[N_PERF_COUNTERS-1:0];
            endcase
        end
    end
    // perf counter registers
    integer ri;
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            id_valid_q <= 1'b0;
            PCER_q     <= {N_PERF_COUNTERS{1'b0}};
            PCMR_q     <= 2'h3;
            for(ri = 0; ri < N_PERF_REGS; ri = ri + 1) 
            begin
                PCCR_q[ri]     <= 32'b0;
                PCCR_inc_q[ri] <= 1'b0;
            end
        end 
        else 
        begin
            id_valid_q <= id_valid_i;
            PCER_q <= PCER_n;
            PCMR_q <= PCMR_n;
            for (ri = 0; ri < N_PERF_REGS; ri = ri + 1) 
            begin
                PCCR_q[ri]     <= PCCR_n[ri];
                PCCR_inc_q[ri] <= PCCR_inc[ri];
            end
        end
    end
endmodule