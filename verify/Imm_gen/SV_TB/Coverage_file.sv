`include "rv32i_defines.vh"

class Coverage_file;
  mailbox #(Transaction) mon2cov;
  Transaction tx;

  logic [3:0]  imm_sel_i;
  logic [31:0] instr_i;
  logic [31:0] imm_o;

  covergroup cg;
    option.per_instance = 1;

    cp_sel : coverpoint imm_sel_i {
      bins i_type   = {`IMMB_I};
      bins s_type   = {`IMMB_S};
      bins u_type   = {`IMMB_U};
      bins pcincr   = {`IMMB_PCINCR};
      bins uj_type  = {`IMMB_UJ};
      bins sb_type  = {`IMMB_SB};
      bins dflt     = default;        
    }

    cp_sign : coverpoint instr_i[31] {
      bins neg = {1'b1};
      bins pos = {1'b0};
    }
    x_sel_sign : cross cp_sel, cp_sign;
  endgroup

  function new(mailbox #(Transaction) mon2cov);
    this.mon2cov = mon2cov;
    cg = new();
  endfunction

  task run();
    forever begin
      mon2cov.get(tx);
      imm_sel_i = tx.imm_sel_i;
      instr_i   = tx.instr_i;
      imm_o     = tx.imm_o;
      cg.sample();
    end
  endtask

  function void report();
    $display("==========================================");
    $display("[COV] coverage = %.2f %%", cg.get_coverage());
    $display("==========================================");
  endfunction

endclass