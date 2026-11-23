// tb_bootrom_eq.sv - checks handover/rtl_synth/rom1p1r_bootrom.sv == sw/boot/rom.hex
// for all 1024 words. Questa (run from neumann_soc/):
//   vlib work_eq
//   vlog -work work_eq -sv handover/rtl_synth/rom1p1r_bootrom.sv handover/check/tb_bootrom_eq.sv
//   vsim -work work_eq -c tb_bootrom_eq -do "run -all; quit -f"
// Expect: "BOOTROM EQ PASS 1024/1024"
module tb_bootrom_eq;
  logic clk = 0, ce = 1;
  logic [9:0] addr = 0;
  logic [31:0] dout;
  logic [31:0] ref_rom [0:1023];
  integer i, ok = 0;
  string hexf;
  rom1p1r #(10, 32, 0) dut (.clk, .ce, .addr, .dout);
  always #5 clk = ~clk;
  initial begin
    if (!$value$plusargs("ROM=%s", hexf)) hexf = "sw/boot/rom.hex";
    for (i = 0; i < 1024; i++) ref_rom[i] = 0;
    $readmemh(hexf, ref_rom);
    for (i = 0; i < 1024; i++) begin
      addr = i[9:0];
      @(posedge clk); #1;
      if (dout === ref_rom[i]) ok++;
      else $display("MISMATCH word %0d addr 0x%08h: got %08h exp %08h", i, 32'h1000 + 4*i, dout, ref_rom[i]);
    end
    $display("BOOTROM EQ %s %0d/1024", (ok == 1024) ? "PASS" : "FAIL", ok);
    $finish;
  end
endmodule
