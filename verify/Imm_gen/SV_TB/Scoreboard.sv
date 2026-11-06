`include "rv32i_defines.vh"
class Scoreboard;
  int pass_count  = 0;
  int fail_count  = 0;
  int total_count = 0;
  mailbox #(Transaction) mon2scb;

  function new(mailbox #(Transaction) mon2scb);
    this.mon2scb = mon2scb;
  endfunction

  task run();
    Transaction tx;
    logic [31:0] expected_data;
    forever begin
      mon2scb.get(tx);
      total_count++;
      expected_data = golden(tx.imm_sel_i, tx.instr_i);
      if (expected_data === tx.imm_o)
        pass_count++;
      else begin
        fail_count++;
        $error("[SCB] MISMATCH sel=%0b instr=%h exp=%h got=%h",
               tx.imm_sel_i, tx.instr_i, expected_data, tx.imm_o);
      end
    end
  endtask

  function logic [31:0] golden(input logic [3:0]  giv_imm_sel_i,
                               input logic [31:0] giv_instr_i);
    case (giv_imm_sel_i)
      `IMMB_I     : return { {20{giv_instr_i[31]}}, giv_instr_i[31:20] };
      `IMMB_S     : return { {20{giv_instr_i[31]}}, giv_instr_i[31:25], giv_instr_i[11:7] };
      `IMMB_SB    : return { {19{giv_instr_i[31]}}, giv_instr_i[31], giv_instr_i[7],
                             giv_instr_i[30:25], giv_instr_i[11:8], 1'b0 };
      `IMMB_U     : return { giv_instr_i[31:12], 12'b0 };
      `IMMB_UJ    : return { {12{giv_instr_i[31]}}, giv_instr_i[19:12], giv_instr_i[20],
                             giv_instr_i[30:21], 1'b0 };
      `IMMB_PCINCR: return 32'd4;
      default     : return 32'b0;
    endcase
  endfunction

  task report();
    $display("==========================================");
    $display("[SCB] total=%0d pass=%0d fail=%0d",
             total_count, pass_count, fail_count);
    $display("==========================================");
    if (fail_count == 0 && total_count > 0)
      $display("[SCB] TEST PASSED");
    else
      $display("[SCB] TEST FAILED");
  endtask
endclass