`include "rv32i_defines.vh"
// ============================================================
// rv32i_debug_unit  (Verilog-2001 port of the .sv reference)
// Internal debug controller: decodes the external debug bus into
// halt/resume, GPR/CSR/DBG-register/PC access. Drives core stall.
// ============================================================
module rv32i_debug_unit
#( parameter REG_ADDR_WIDTH = 5 )
(
  input  clk,
  input  rst_n,
  // Debug bus
  input         debug_req_i,
  output reg    debug_gnt_o,
  output reg    debug_rvalid_o,
  input  [14:0] debug_addr_i,
  input         debug_we_i,
  input  [31:0] debug_wdata_i,
  output reg [31:0] debug_rdata_o,
  output reg    debug_halted_o,
  input         debug_halt_i,
  input         debug_resume_i,
  // to core
  output [`DBG_SETS_W-1:0] settings_o,
  input         trap_i,
  input  [5:0]  exc_cause_i,
  output reg    stall_o,
  output reg    dbg_req_o,
  input         dbg_ack_i,
  // regfile read
  output        regfile_rreq_o,
  output [(REG_ADDR_WIDTH-1):0] regfile_raddr_o,
  input  [31:0] regfile_rdata_i,
  // regfile write
  output        regfile_wreq_o,
  output [(REG_ADDR_WIDTH-1):0] regfile_waddr_o,
  output [31:0] regfile_wdata_o,
  // CSR
  output        csr_req_o,
  output [11:0] csr_addr_o,
  output reg    csr_we_o,
  output [31:0] csr_wdata_o,
  input  [31:0] csr_rdata_i,
  // PC
  input  [31:0] pc_if_i,
  input  [31:0] pc_id_i,
  input         instr_valid_id_i,
  input         sleeping_i,
  output        jump_req_o,
  output [31:0] jump_addr_o
);
  // rdata_sel encoding
  localparam RD_NONE=3'd0, RD_CSR=3'd1, RD_GPR=3'd2, RD_DBGA=3'd3, RD_DBGS=3'd4;
  localparam FIRST=1'b0, SECOND=1'b1;
  localparam RUNNING=2'd0, HALT_REQ=2'd1, HALT=2'd2;

  reg  [2:0] rdata_sel_q, rdata_sel_n;
  reg        state_q, state_n;
  reg  [`DBG_SETS_W-1:0] settings_q, settings_n;

  reg  [14:0] addr_q;
  reg  [31:0] wdata_q;
  reg         regfile_rreq_q, regfile_rreq_n;
  reg         jump_req_q, jump_req_n;
  reg         csr_req_q, csr_req_n;
  reg         regfile_wreq;

  reg  [1:0] stall_cs, stall_ns;
  reg  [31:0] dbg_rdata;
  reg         dbg_resume, dbg_halt;
  reg  [5:0]  dbg_cause_q, dbg_cause_n;
  reg         dbg_ssth_q, dbg_ssth_n;
  reg         ssth_clear;
  wire [31:0] ppc_int, npc_int;

  // ---- address decode / write+read controller ----
  always @(*) begin
    rdata_sel_n   = RD_NONE;
    state_n       = FIRST;
    debug_gnt_o   = 1'b0;
    regfile_rreq_n= 1'b0;
    regfile_wreq  = 1'b0;
    csr_req_n     = 1'b0;
    csr_we_o      = 1'b0;
    jump_req_n    = 1'b0;
    dbg_resume    = 1'b0;
    dbg_halt      = 1'b0;
    settings_n    = settings_q;
    ssth_clear    = 1'b0;

    if (debug_req_i) begin
      if (debug_we_i) begin
        // ---- write ----
        if (debug_addr_i[14]) begin
          if (state_q == FIRST) begin
            debug_gnt_o = 1'b0;
            state_n     = SECOND;
            if (debug_halted_o) csr_req_n = 1'b1;
          end else begin
            debug_gnt_o = 1'b1;
            state_n     = FIRST;
            csr_we_o    = 1'b1;
          end
        end else begin
          case (debug_addr_i[13:8])
            6'b00_0000: begin
              debug_gnt_o = 1'b1;
              case (debug_addr_i[6:2])
                5'b0_0000: begin // DBG_CTRL
                  if (debug_wdata_i[16]) begin
                    if (~debug_halted_o) dbg_halt = 1'b1;
                  end else begin
                    if (debug_halted_o)  dbg_resume = 1'b1;
                  end
                  settings_n[`DBG_SETS_SSTE] = debug_wdata_i[0];
                end
                5'b0_0001: ssth_clear = debug_wdata_i[0]; // DBG_HIT
                5'b0_0010: begin // DBG_IE
                  settings_n[`DBG_SETS_ECALL] = debug_wdata_i[11];
                  settings_n[`DBG_SETS_ELSU]  = debug_wdata_i[7] | debug_wdata_i[5];
                  settings_n[`DBG_SETS_EBRK]  = debug_wdata_i[3];
                  settings_n[`DBG_SETS_EILL]  = debug_wdata_i[2];
                end
                default: ;
              endcase
            end
            6'b10_0000: begin
              debug_gnt_o = 1'b1;
              if (debug_halted_o)
                if (debug_addr_i[6:2]==5'b0_0000) jump_req_n = 1'b1; // DNPC
            end
            6'b00_0100: begin // GPR write
              debug_gnt_o = 1'b1;
              if (debug_halted_o) regfile_wreq = 1'b1;
            end
            default: debug_gnt_o = 1'b1;
          endcase
        end
      end else begin
        // ---- read ----
        if (debug_addr_i[14]) begin
          debug_gnt_o = 1'b1;
          if (debug_halted_o) begin
            csr_req_n   = 1'b1;
            rdata_sel_n = RD_CSR;
          end
        end else begin
          case (debug_addr_i[13:8])
            6'b00_0000: begin debug_gnt_o=1'b1; rdata_sel_n=RD_DBGA; end
            6'b10_0000: begin debug_gnt_o=1'b1; rdata_sel_n=RD_DBGS; end
            6'b00_0100: begin // GPR read
              debug_gnt_o = 1'b1;
              if (debug_halted_o) begin
                regfile_rreq_n = 1'b1;
                rdata_sel_n    = RD_GPR;
              end
            end
            default: debug_gnt_o = 1'b1;
          endcase
        end
      end
    end
  end

  // ---- debug register read ----
  always @(*) begin
    dbg_rdata = 32'b0;
    case (rdata_sel_q)
      RD_DBGA: begin
        case (addr_q[6:2])
          5'h00: dbg_rdata = {15'b0, debug_halted_o, 15'b0, settings_q[`DBG_SETS_SSTE]};
          5'h01: dbg_rdata = {15'b0, sleeping_i, 15'b0, dbg_ssth_q};
          5'h02: begin
            dbg_rdata = 32'b0;
            dbg_rdata[11] = settings_q[`DBG_SETS_ECALL];
            dbg_rdata[7]  = settings_q[`DBG_SETS_ELSU];
            dbg_rdata[5]  = settings_q[`DBG_SETS_ELSU];
            dbg_rdata[3]  = settings_q[`DBG_SETS_EBRK];
            dbg_rdata[2]  = settings_q[`DBG_SETS_EILL];
          end
          5'h03: dbg_rdata = {dbg_cause_q[5], 26'b0, dbg_cause_q[4:0]};
          default: dbg_rdata = 32'b0;
        endcase
      end
      RD_DBGS: begin
        case (addr_q[2])
          1'b0: dbg_rdata = npc_int;
          1'b1: dbg_rdata = ppc_int;
        endcase
      end
      default: dbg_rdata = 32'b0;
    endcase
  end

  // ---- read data mux ----
  always @(*) begin
    debug_rdata_o = 32'b0;
    case (rdata_sel_q)
      RD_CSR:  debug_rdata_o = csr_rdata_i;
      RD_GPR:  debug_rdata_o = regfile_rdata_i;
      RD_DBGA: debug_rdata_o = dbg_rdata;
      RD_DBGS: debug_rdata_o = dbg_rdata;
      default: debug_rdata_o = 32'b0;
    endcase
  end

  // ---- rvalid ----
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) debug_rvalid_o <= 1'b0;
    else        debug_rvalid_o <= debug_gnt_o;
  end

  // ---- stall control FSM ----
  always @(*) begin
    stall_ns       = stall_cs;
    dbg_req_o      = 1'b0;
    stall_o        = 1'b0;
    debug_halted_o = 1'b0;
    dbg_cause_n    = dbg_cause_q;
    dbg_ssth_n     = dbg_ssth_q;
    case (stall_cs)
      RUNNING: begin
        dbg_ssth_n = 1'b0;
        if (dbg_halt | debug_halt_i | trap_i) begin
          dbg_req_o = 1'b1;
          stall_ns  = HALT_REQ;
          if (trap_i) begin
            if (settings_q[`DBG_SETS_SSTE]) dbg_ssth_n = 1'b1;
            dbg_cause_n = exc_cause_i;
          end else begin
            dbg_cause_n = `DBG_CAUSE_HALT;
          end
        end
      end
      HALT_REQ: begin
        dbg_req_o = 1'b1;
        if (dbg_ack_i) stall_ns = HALT;
        if (dbg_resume | debug_resume_i) stall_ns = RUNNING;
      end
      HALT: begin
        stall_o        = 1'b1;
        debug_halted_o = 1'b1;
        if (dbg_resume | debug_resume_i) begin
          stall_ns = RUNNING;
          stall_o  = 1'b0;
        end
      end
      default: stall_ns = RUNNING;
    endcase
    if (ssth_clear) dbg_ssth_n = 1'b0;
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      stall_cs    <= RUNNING;
      dbg_cause_q <= `DBG_CAUSE_HALT;
      dbg_ssth_q  <= 1'b0;
    end else begin
      stall_cs    <= stall_ns;
      dbg_cause_q <= dbg_cause_n;
      dbg_ssth_q  <= dbg_ssth_n;
    end
  end

  assign ppc_int = pc_id_i;
  assign npc_int = pc_if_i;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      addr_q<=15'b0; wdata_q<=32'b0; state_q<=FIRST; rdata_sel_q<=RD_NONE;
      regfile_rreq_q<=1'b0; csr_req_q<=1'b0; jump_req_q<=1'b0; settings_q<={`DBG_SETS_W{1'b0}};
    end else begin
      settings_q <= settings_n;
      if (debug_req_i) begin
        addr_q  <= debug_addr_i;
        wdata_q <= debug_wdata_i;
        state_q <= state_n;
      end
      if (debug_req_i | debug_rvalid_o) begin
        regfile_rreq_q <= regfile_rreq_n;
        csr_req_q      <= csr_req_n;
        jump_req_q     <= jump_req_n;
        rdata_sel_q    <= rdata_sel_n;
      end
    end
  end

  assign regfile_rreq_o  = regfile_rreq_q;
  assign regfile_raddr_o = addr_q[6:2];
  assign regfile_wreq_o  = regfile_wreq;
  assign regfile_waddr_o = debug_addr_i[6:2];
  assign regfile_wdata_o = debug_wdata_i;
  assign csr_req_o       = csr_req_q;
  assign csr_addr_o      = addr_q[13:2];
  assign csr_wdata_o     = wdata_q;
  assign jump_req_o      = jump_req_q;
  assign jump_addr_o     = wdata_q;
  assign settings_o      = settings_q;
endmodule
