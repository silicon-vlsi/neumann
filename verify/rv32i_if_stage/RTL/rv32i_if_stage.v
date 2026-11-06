`include "rv32i_defines.vh"

module rv32i_if_stage
(
    input         clk,
    input         rst_n,

    input  [31:0] boot_addr_i,
    input         req_i,

    // Instruction memory interface
    output        instr_req_o,
    output [31:0] instr_addr_o,
    input         instr_gnt_i,
    input         instr_rvalid_i,
    input  [31:0] instr_rdata_i,

    // Outputs to ID stage
    output reg        instr_valid_id_o,
    output reg [31:0] instr_rdata_id_o,
    output reg        is_compressed_id_o,
    output reg        illegal_c_insn_id_o,
    output     [31:0] pc_if_o,
    output reg [31:0] pc_id_o,

    // Control signals from ID/controller
    input         clear_instr_valid_i,
    input         pc_set_i,
    input  [31:0] exception_pc_reg_i,
    input  [2:0]  pc_mux_i,
    input  [1:0]  exc_pc_mux_i,
    input  [4:0]  exc_vec_pc_mux_i,
    input  [31:0] jump_target_ex_i,
    input  [31:0] dbg_jump_addr_i,
    input         halt_if_i,
    input         id_ready_i,

    output        if_valid_o,
    output        if_busy_o,
    output        perf_imiss_o
);
    localparam IDLE = 1'b1;
    localparam WAIT = 1'b0;

    reg        offset_fsm_cs, offset_fsm_ns;
    reg        valid;
    reg        branch_req; 
    reg        fetch_ready;
    reg [31:0] fetch_addr_n;
    reg [31:0] exc_pc;

    wire        prefetch_busy;
    wire        fetch_valid;
    wire [31:0] fetch_rdata;
    wire [31:0] fetch_addr;
    wire        if_ready;
    always @(*) begin
        exc_pc = 32'b0;
        case (exc_pc_mux_i)
            `EXC_PC_ILLINSN: exc_pc = {boot_addr_i[31:8], `EXC_OFF_ILLINSN};
            `EXC_PC_ECALL:   exc_pc = {boot_addr_i[31:8], `EXC_OFF_ECALL};
            `EXC_PC_IRQ:     exc_pc = {boot_addr_i[31:8], 1'b0,
                                        exc_vec_pc_mux_i[4:0], 2'b0};
            default:;
        endcase
    end
    always @(*) begin
        fetch_addr_n = 32'b0;
        case (pc_mux_i)
            `PC_BOOT:      fetch_addr_n = {boot_addr_i[31:8], `EXC_OFF_RST};
            `PC_JUMP:      fetch_addr_n = jump_target_ex_i;
            `PC_EXCEPTION: fetch_addr_n = exc_pc;
            `PC_ERET:      fetch_addr_n = exception_pc_reg_i;
            `PC_DBG_NPC:   fetch_addr_n = dbg_jump_addr_i;
            default:;
        endcase
    end
    rv32i_prefetch_buffer prefetch_i
    (
        .clk             (clk),
        .rst_n           (rst_n),
        .req_i           (req_i),
        .branch_i        (branch_req),
        .addr_i          ({fetch_addr_n[31:1], 1'b0}),
        .ready_i         (fetch_ready),
        .valid_o         (fetch_valid),
        .rdata_o         (fetch_rdata),
        .addr_o          (fetch_addr),
        .instr_req_o     (instr_req_o),
        .instr_addr_o    (instr_addr_o),
        .instr_gnt_i     (instr_gnt_i),
        .instr_rvalid_i  (instr_rvalid_i),
        .instr_rdata_i   (instr_rdata_i),
        .busy_o          (prefetch_busy)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            offset_fsm_cs <= IDLE;
        else
            offset_fsm_cs <= offset_fsm_ns;
    end
    always @(*) begin
        offset_fsm_ns = offset_fsm_cs;
        fetch_ready   = 1'b0;
        branch_req    = 1'b0;
        valid         = 1'b0;

        case (offset_fsm_cs)

            IDLE: begin
                if (req_i) begin
                    branch_req    = 1'b1;
                    offset_fsm_ns = WAIT;
                end
            end
            WAIT: begin
                if (fetch_valid) begin
                    valid = 1'b1;
                    if (req_i && (~halt_if_i) && id_ready_i) begin
                        fetch_ready   = 1'b1;
                        offset_fsm_ns = WAIT;
                    end
                end
            end

            default: offset_fsm_ns = IDLE;

        endcase
         if (pc_set_i) begin
            valid         = 1'b0;
            branch_req    = 1'b1;
            offset_fsm_ns = WAIT;
        end
    end
    wire [31:0] instr_decompressed;
    wire        illegal_c_insn;
    wire        instr_compressed_int;
    rv32i_compressed_decoder compressed_dec_i
    (
        .instr_i         (fetch_rdata),
        .instr_o         (instr_decompressed),
        .is_compressed_o (instr_compressed_int),
        .illegal_instr_o (illegal_c_insn)
    );
   always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_valid_id_o    <= 1'b0;
            instr_rdata_id_o    <= 32'b0;
            illegal_c_insn_id_o <= 1'b0;
            is_compressed_id_o  <= 1'b0;
            pc_id_o             <= 32'b0;
        end else begin
            if (if_valid_o) begin
                instr_valid_id_o    <= 1'b1;
                instr_rdata_id_o    <= instr_decompressed;
                illegal_c_insn_id_o <= illegal_c_insn;
                is_compressed_id_o  <= instr_compressed_int;
                pc_id_o             <= pc_if_o;
            end else if (clear_instr_valid_i) begin
                instr_valid_id_o    <= 1'b0;
            end
        end
    end
    assign if_ready     = valid & id_ready_i;
    assign if_valid_o   = (~halt_if_i) & if_ready;
    assign pc_if_o      = fetch_addr;
    assign if_busy_o    = prefetch_busy;
    assign perf_imiss_o = (~fetch_valid) | branch_req;

endmodule