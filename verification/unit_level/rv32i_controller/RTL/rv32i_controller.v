`include "rv32i_defines.vh"
module rv32i_controller
#(
  parameter REG_ADDR_WIDTH = 5
)
(
  input  wire clk,
  input  wire rst_n,
  input  wire fetch_enable_i,          // Start decoding
  output reg  ctrl_busy_o,      // Core is busy processing instructions
  output reg  first_fetch_o,    // Core is at the FIRST_FETCH stage
  output reg  is_decoding_o,    // Core is in decoding state
  // Decoder related signals
  output reg  deassert_we_o,    // Deassert write-enable for current instruction
  input  wire illegal_insn_i,   // Decoder: illegal instruction
  input  wire ecall_insn_i,     // Decoder: ECALL instruction
  input  wire mret_insn_i,      // Decoder: MRET instruction
  input  wire pipe_flush_i,     // Decoder: pipeline flush (WFI)
  input  wire ebrk_insn_i,      // Decoder: EBREAK instruction
  input  wire csr_status_i,     // Decoder: CSR status instruction
  // From IF/ID pipeline
  input  wire instr_valid_i,    // Instruction from IF/ID is valid
  // To/from prefetcher
  output reg  instr_req_o,      // Start fetching instructions
  output reg  pc_set_o,  // Jump to address set by pc_mux
  output reg  [2:0]  pc_mux_o, // PC mux selector (boot/jump/exception/...)
  output reg  [1:0]  exc_pc_mux_o,     // Exception PC target selector
  // LSU
  input  wire data_misaligned_i,
  // Jump / Branch signals
  input  wire branch_in_id_i,   // Branch instruction in ID
  input  wire branch_taken_ex_i,// Branch taken in EX
  input  wire branch_set_i,     // Branch taken set (pipelined)
  input  wire jump_set_i,// Jump set signal
  input  wire instr_multicyle_i,// Multi-cycle instruction active
  // Interrupt Controller signals
  input  wire irq_req_ctrl_i,
  input  wire [4:0]  irq_id_ctrl_i,
  input  wire m_IE_i,    // Machine interrupt enable from CSR
  output reg  irq_ack_o,
  output reg  [4:0]  irq_id_o,
  output reg  [5:0]  exc_cause_o,
  output reg  exc_ack_o,
  output reg  exc_kill_o,
  output reg  csr_save_if_o,
  output reg  csr_save_id_o,
  output reg  [5:0]  csr_cause_o,
  output reg  csr_restore_mret_id_o,
  output reg  csr_save_cause_o,
  // Debug Unit signals
  input  wire dbg_req_i, // Debug trap hit; flush EX and WB
  output reg  dbg_ack_o, // Stopped; debug unit has control
  input  wire dbg_stall_i,      // Pipeline stall requested by debug
  input  wire dbg_jump_req_i,   // Change PC to debug NPC
  input  wire [`DBG_SETS_W-1:0] dbg_settings_i,
  output reg  dbg_trap_o,
  // Forwarding signals
  output wire [1:0]  operand_a_fw_mux_sel_o,  // Operand A forward select
  // Stall signals
  output reg  halt_if_o,
  output reg  halt_id_o,
  input  wire id_ready_i,// ID stage is ready
  // Performance Counters
  output reg  perf_jump_o,      // Executing a jump instruction
  output reg  perf_tbranch_o           // Executing a taken branch
);
 
  //--------------------------------------------------------------------------
  // FSM state encoding
  //--------------------------------------------------------------------------
  // 13 states encoded as 4-bit one-hot-friendly binary
  localparam [3:0] RESET             = 4'd0;
  localparam [3:0] BOOT_SET          = 4'd1;
  localparam [3:0] WAIT_SLEEP        = 4'd2;
  localparam [3:0] SLEEP             = 4'd3;
  localparam [3:0] FIRST_FETCH       = 4'd4;
  localparam [3:0] DECODE            = 4'd5;
  localparam [3:0] FLUSH             = 4'd6;
  localparam [3:0] IRQ_TAKEN         = 4'd7;
  localparam [3:0] DBG_SIGNAL        = 4'd8;
  localparam [3:0] DBG_SIGNAL_SLEEP  = 4'd9;
  localparam [3:0] DBG_WAIT          = 4'd10;
  localparam [3:0] DBG_WAIT_BRANCH   = 4'd11;
  localparam [3:0] DBG_WAIT_SLEEP    = 4'd12;
 
  reg [3:0] ctrl_fsm_cs;
  reg [3:0] ctrl_fsm_ns;
 
  reg        irq_enable_int;
 
  //--------------------------------------------------------------------------
  // Controller FSM  - Combinational
  //--------------------------------------------------------------------------
  always @(*)
  begin
    // ----- Default values -----
    instr_req_o            = 1'b1;
 
    exc_ack_o              = 1'b0;
    exc_kill_o             = 1'b0;
 
    csr_save_if_o          = 1'b0;
    csr_save_id_o          = 1'b0;
    csr_restore_mret_id_o  = 1'b0;
    csr_save_cause_o       = 1'b0;
 
    exc_cause_o            = 6'b0;
    exc_pc_mux_o           = `EXC_PC_IRQ;
 
    csr_cause_o            = 6'b0;
 
    pc_mux_o               = `PC_BOOT;
    pc_set_o               = 1'b0;
 
    ctrl_fsm_ns            = ctrl_fsm_cs;
 
    ctrl_busy_o            = 1'b1;
    is_decoding_o          = 1'b0;
    first_fetch_o          = 1'b0;
 
    halt_if_o              = 1'b0;
    halt_id_o              = 1'b0;
    dbg_ack_o              = 1'b0;
    irq_ack_o              = 1'b0;
    irq_id_o               = irq_id_ctrl_i;
    irq_enable_int         = m_IE_i;
 
    dbg_trap_o             = 1'b0;
 
    perf_tbranch_o         = 1'b0;
    perf_jump_o            = 1'b0;
 
    case (ctrl_fsm_cs)
 
      //----------------------------------------------------------------------
      // RESET: Wait for fetch_enable or debug request
      //----------------------------------------------------------------------
      RESET:
      begin
        ctrl_busy_o = 1'b0;
        instr_req_o = 1'b0;
 
        if (fetch_enable_i)
          ctrl_fsm_ns = BOOT_SET;
        else if (dbg_req_i)
          ctrl_fsm_ns = DBG_SIGNAL;
      end
 
      //----------------------------------------------------------------------
      // BOOT_SET: Copy boot address to instruction fetch address
      //----------------------------------------------------------------------
      BOOT_SET:
      begin
        instr_req_o = 1'b1;
        pc_mux_o    = `PC_BOOT;
        pc_set_o    = 1'b1;
 
        ctrl_fsm_ns = FIRST_FETCH;
      end
 
      //----------------------------------------------------------------------
      // WAIT_SLEEP: Transition cycle before sleeping
      //----------------------------------------------------------------------
      WAIT_SLEEP:
      begin
        ctrl_busy_o = 1'b0;
        instr_req_o = 1'b0;
        halt_if_o   = 1'b1;
        halt_id_o   = 1'b1;
        ctrl_fsm_ns = SLEEP;
      end
 
      //----------------------------------------------------------------------
      // SLEEP: Core is sleeping; wake on fetch_enable or IRQ
      //----------------------------------------------------------------------
      SLEEP:
      begin
        ctrl_busy_o = 1'b0;
        instr_req_o = 1'b0;
        halt_if_o   = 1'b1;
        halt_id_o   = 1'b1;
        dbg_trap_o  = dbg_settings_i[`DBG_SETS_SSTE];
 
        if (dbg_req_i) begin
          if (fetch_enable_i || irq_req_ctrl_i)
            ctrl_fsm_ns = DBG_SIGNAL;
          else
            ctrl_fsm_ns = DBG_SIGNAL_SLEEP;
        end else begin
          if (fetch_enable_i || irq_req_ctrl_i)
            ctrl_fsm_ns = FIRST_FETCH;
        end
      end
 
      //----------------------------------------------------------------------
      // FIRST_FETCH: Wait for first valid instruction from I-cache
      //----------------------------------------------------------------------
      FIRST_FETCH:
      begin
        first_fetch_o = 1'b1;
 
        if ((id_ready_i == 1'b1) && (dbg_stall_i == 1'b0))
          ctrl_fsm_ns = DECODE;
 
        if (irq_req_ctrl_i & irq_enable_int) begin
          ctrl_fsm_ns = IRQ_TAKEN;
          halt_if_o   = 1'b1;
          halt_id_o   = 1'b1;
        end
      end
 
      //----------------------------------------------------------------------
      // DECODE: Normal instruction decode and issue
      //----------------------------------------------------------------------
      DECODE:
      begin
        is_decoding_o = 1'b0;
 
        if (instr_valid_i) begin
          is_decoding_o = 1'b1;
 
          // Priority-encoded event handling
          if (branch_set_i) begin
            pc_mux_o       = `PC_JUMP;
            pc_set_o       = 1'b1;
            perf_tbranch_o = 1'b1;
            dbg_trap_o     = dbg_settings_i[`DBG_SETS_SSTE];
            if (dbg_req_i)
              ctrl_fsm_ns = DBG_SIGNAL;
 
          end else if (jump_set_i) begin
            pc_mux_o    = `PC_JUMP;
            pc_set_o    = 1'b1;
            perf_jump_o = 1'b1;
            dbg_trap_o  = dbg_settings_i[`DBG_SETS_SSTE];
 
          end else if (mret_insn_i  | ecall_insn_i | pipe_flush_i |
                       ebrk_insn_i  | illegal_insn_i | csr_status_i) begin
            ctrl_fsm_ns = FLUSH;
            halt_if_o   = 1'b1;
            halt_id_o   = 1'b1;
 
          end else begin
            // Normal decode; check for debug / IRQ
            dbg_trap_o = dbg_settings_i[`DBG_SETS_SSTE];
 
            if (irq_req_ctrl_i & irq_enable_int &
                (~instr_multicyle_i) & (~branch_in_id_i)) begin
              ctrl_fsm_ns = IRQ_TAKEN;
              halt_if_o   = 1'b1;
              halt_id_o   = 1'b1;
 
            end else if (dbg_req_i & (~branch_taken_ex_i)) begin
              halt_if_o = 1'b1;
              if (id_ready_i)
                ctrl_fsm_ns = DBG_SIGNAL;
 
            end else begin
              exc_kill_o = (irq_req_ctrl_i & (~instr_multicyle_i) &
                            (~branch_in_id_i)) ? 1'b1 : 1'b0;
            end
          end
 
        end else begin
          // ~instr_valid_i: check for IRQ while pipeline is empty
          if (irq_req_ctrl_i & irq_enable_int) begin
            ctrl_fsm_ns = IRQ_TAKEN;
            halt_if_o   = 1'b1;
            halt_id_o   = 1'b1;
          end
        end
      end
 
      //----------------------------------------------------------------------
      // DBG_SIGNAL: Signal to debug unit that pipeline is empty
      //----------------------------------------------------------------------
      DBG_SIGNAL:
      begin
        dbg_ack_o   = 1'b1;
        halt_if_o   = 1'b1;
        ctrl_fsm_ns = DBG_WAIT;
      end
 
      //----------------------------------------------------------------------
      // DBG_SIGNAL_SLEEP: Signal to debug unit; will return to SLEEP
      //----------------------------------------------------------------------
      DBG_SIGNAL_SLEEP:
      begin
        dbg_ack_o   = 1'b1;
        halt_if_o   = 1'b1;
        ctrl_fsm_ns = DBG_WAIT_SLEEP;
      end
 
      //----------------------------------------------------------------------
      // DBG_WAIT_SLEEP: Debug unit active; return to SLEEP when done
      //----------------------------------------------------------------------
      DBG_WAIT_SLEEP:
      begin
        halt_if_o = 1'b1;
 
        if (dbg_jump_req_i) begin
          pc_mux_o    = `PC_DBG_NPC;
          pc_set_o    = 1'b1;
          ctrl_fsm_ns = DBG_WAIT;
        end
 
        if (~dbg_stall_i)
          ctrl_fsm_ns = SLEEP;
      end
 
      //----------------------------------------------------------------------
      // DBG_WAIT: Debug unit active; return to DECODE when done
      //----------------------------------------------------------------------
      DBG_WAIT:
      begin
        halt_if_o = 1'b1;
 
        if (dbg_jump_req_i) begin
          pc_mux_o    = `PC_DBG_NPC;
          pc_set_o    = 1'b1;
          ctrl_fsm_ns = DBG_WAIT;
        end
 
        if (~dbg_stall_i)
          ctrl_fsm_ns = DECODE;
      end
 
      //----------------------------------------------------------------------
      // IRQ_TAKEN: Accept interrupt, redirect PC to exception handler
      //----------------------------------------------------------------------
      IRQ_TAKEN:
      begin
        pc_mux_o         = `PC_EXCEPTION;
        pc_set_o         = 1'b1;
 
        exc_pc_mux_o     = `EXC_PC_IRQ;
        exc_cause_o      = {1'b0, irq_id_ctrl_i};
 
        csr_save_cause_o = 1'b1;
        csr_cause_o      = {1'b1, irq_id_ctrl_i};
 
        csr_save_if_o    = 1'b1;
 
        irq_ack_o        = 1'b1;
        exc_ack_o        = 1'b1;
 
        ctrl_fsm_ns      = DECODE;
      end
 
      //----------------------------------------------------------------------
      // FLUSH: Flush pipeline; handle exception/syscall/mret/wfi
      //----------------------------------------------------------------------
      FLUSH:
      begin
        halt_if_o   = fetch_enable_i ? dbg_req_i : 1'b1;
        halt_id_o   = 1'b1;
 
        // Default next state (overridden below per case)
        ctrl_fsm_ns = dbg_req_i ? DBG_SIGNAL : DECODE;
 
        // Exception / special instruction handling
        if (ecall_insn_i) begin
          pc_mux_o              = `PC_EXCEPTION;
          pc_set_o              = 1'b1;
          csr_save_id_o         = 1'b1;
          csr_save_cause_o      = 1'b1;
          exc_pc_mux_o          = `EXC_PC_ECALL;
          exc_cause_o           = `EXC_CAUSE_ECALL_MMODE;
          csr_cause_o           = `EXC_CAUSE_ECALL_MMODE;
          dbg_trap_o            = dbg_settings_i[`DBG_SETS_ECALL] |
                                  dbg_settings_i[`DBG_SETS_SSTE];
 
        end else if (illegal_insn_i) begin
          pc_mux_o              = `PC_EXCEPTION;
          pc_set_o              = 1'b1;
          csr_save_id_o         = 1'b1;
          csr_save_cause_o      = 1'b1;
          exc_pc_mux_o          = `EXC_PC_ILLINSN;
          exc_cause_o           = `EXC_CAUSE_ILLEGAL_INSN;
          csr_cause_o           = `EXC_CAUSE_ILLEGAL_INSN;
          dbg_trap_o            = dbg_settings_i[`DBG_SETS_EILL] |
                                  dbg_settings_i[`DBG_SETS_SSTE];
 
        end else if (mret_insn_i) begin
          pc_mux_o              = `PC_ERET;
          pc_set_o              = 1'b1;
          csr_restore_mret_id_o = 1'b1;
          dbg_trap_o            = dbg_settings_i[`DBG_SETS_SSTE];
 
        end else if (ebrk_insn_i) begin
          dbg_trap_o            = dbg_settings_i[`DBG_SETS_EBRK] |
                                  dbg_settings_i[`DBG_SETS_SSTE];
          exc_cause_o           = `EXC_CAUSE_BREAKPOINT;
 
        end else if (csr_status_i) begin
          dbg_trap_o            = dbg_settings_i[`DBG_SETS_SSTE];
 
        end else if (pipe_flush_i) begin
          dbg_trap_o            = dbg_settings_i[`DBG_SETS_SSTE];
        end
 
        // Final next-state override based on fetch_enable / dbg_req
        if (fetch_enable_i) begin
          ctrl_fsm_ns = dbg_req_i ? DBG_SIGNAL : DECODE;
        end else begin
          if (dbg_req_i)
            ctrl_fsm_ns = DBG_SIGNAL_SLEEP;
          else
            ctrl_fsm_ns = (mret_insn_i | pipe_flush_i) ? WAIT_SLEEP : DECODE;
        end
      end
 
      //----------------------------------------------------------------------
      // Default: should never be reached; safe return to RESET
      //----------------------------------------------------------------------
      default:
      begin
        instr_req_o = 1'b0;
        ctrl_fsm_ns = RESET;
      end
 
    endcase
  end // always @(*)
 
  //--------------------------------------------------------------------------
  // Stall control: deassert_we combinational block
  //--------------------------------------------------------------------------
  always @(*)
  begin
    deassert_we_o = 1'b0;
 
    // Deassert WE when not decoding
    if (~is_decoding_o)
      deassert_we_o = 1'b1;
 
    // Deassert WE on illegal instruction
    if (illegal_insn_i)
      deassert_we_o = 1'b1;
  end
 
  //--------------------------------------------------------------------------
  // Forwarding control: misaligned address takes priority
  //--------------------------------------------------------------------------
  assign operand_a_fw_mux_sel_o = data_misaligned_i ? `SEL_MISALIGNED : `SEL_REGFILE;
 
  //--------------------------------------------------------------------------
  // FSM state register (sequential)
  //--------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n)
  begin : UPDATE_REGS
    if (~rst_n)
      ctrl_fsm_cs <= RESET;
    else
      ctrl_fsm_cs <= ctrl_fsm_ns;
  end
 
endmodule