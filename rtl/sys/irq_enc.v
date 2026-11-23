// =============================================================================
// irq_enc.v
// SoC interrupt lines -> neumann core irq_i / irq_id_i.
//
// Part of neumann_soc (neumann core on Wally uncore).
//
// The core takes one interrupt at a time: in IDLE it samples irq_i & mstatus.MIE,
// latches irq_id_i, and jumps to mtvec + 4*id with mcause = 0x8000_0000 + id.
// All SoC sources are level-sensitive and stay high until software clears them
// at the source (write mtimecmp, clear msip, PLIC claim/complete), so a plain
// combinational priority encoder is enough; nothing has to be held here.
//
// IDs follow the RISC-V mcause interrupt codes:
//   MEI (PLIC MExtInt)   -> 11   vector mtvec + 0x2C   (highest)
//   MSI (CLINT msip)     ->  3   vector mtvec + 0x0C
//   MTI (CLINT mtimecmp) ->  7   vector mtvec + 0x1C   (lowest)
// Priority order MEI > MSI > MTI is the RISC-V privileged-spec order.
// =============================================================================
module irq_enc (
    input        mei_i,
    input        msi_i,
    input        mti_i,
    output       irq_o,
    output [4:0] irq_id_o
);
    assign irq_o    = mei_i | msi_i | mti_i;
    assign irq_id_o = mei_i ? 5'd11 :
                      msi_i ? 5'd3  :
                      mti_i ? 5'd7  : 5'd0;
endmodule
