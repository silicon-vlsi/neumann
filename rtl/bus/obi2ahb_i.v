// =============================================================================
// obi2ahb_i.v
// neumann instruction port (OBI-style) -> AHB-Lite master, ebu3 master 0 (IFU)
//
// Part of neumann_soc (neumann core on Wally uncore).
//
// Core side (instr port of rv32i_core):
//   instr_req_o / instr_gnt_i / instr_rvalid_i / instr_addr_o / instr_rdata_i
//   - one transfer outstanding at most
//   - address may change while req is high and gnt is low (branch in WAIT_GNT)
//   - a new req may come in the same cycle as rvalid of the previous one
//
// AHB side (to ebu3 IFUH* inputs):
//   Same convention as Wally's busfsm:
//     HTRANS = NONSEQ only in the cycle the address phase is accepted,
//     i.e. HTRANS = req & ~hold_i & HREADY.
//   So an address phase is never left waiting on the bus, and an address that
//   changes before gnt never reaches the bus.
//
//   gnt    = req & HREADY & ~hold_i
//   rvalid = data phase pending & HREADY
//   Reads are always 32-bit, word-aligned (HADDR[1:0] = 00). The core's fetch
//   FIFO uses its own address to pick halfwords for RVC.
//
// hold_i = ~IFUHGRANT from ebu3: the IFU is the lowest-priority master, so it
// waits (req held, no address phase) while the LSU or the debug unit wants
// the bus. Tie to 0 if this bridge is the only master.
//
// Instruction side has no error input on the core. instr_err_o = HRESP at the
// end of the data phase is given for the SoC to use (e.g. a sticky status bit).
// =============================================================================
module obi2ahb_i #(
    parameter PA_BITS = 32
) (
    input                    HCLK,
    input                    HRESETn,

    // ---- OBI-style slave, from core instr port ----
    input                    instr_req_i,
    /* verilator lint_off UNUSEDSIGNAL */  // [1:0] unused: fetch is word-aligned
    input      [31:0]        instr_addr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    output                   instr_gnt_o,
    output                   instr_rvalid_o,
    output     [31:0]        instr_rdata_o,
    output                   instr_err_o,

    // ---- AHB-Lite master, to EBU IFU port ----
    output     [1:0]         HTRANS,
    output     [2:0]         HSIZE,
    output     [2:0]         HBURST,
    output     [PA_BITS-1:0] HADDR,
    input                    HREADY,     // IFUHREADY from EBU
    input      [31:0]        HRDATA,
    input                    HRESP,
    input                    hold_i      // 1: do not start a new fetch this cycle
);

    reg dphase_q;   // 1: our data phase is on the bus

    assign instr_gnt_o    = instr_req_i & HREADY & ~hold_i;
    assign instr_rvalid_o = dphase_q & HREADY;
    assign instr_rdata_o  = HRDATA;
    assign instr_err_o    = dphase_q & HREADY & HRESP;

    assign HTRANS = instr_gnt_o ? 2'b10 : 2'b00;   // NONSEQ or IDLE
    assign HSIZE  = 3'b010;                        // word
    assign HBURST = 3'b000;                        // SINGLE

    generate
        if (PA_BITS > 32) begin : g_pa_wide
            assign HADDR = {{(PA_BITS-32){1'b0}}, instr_addr_i[31:2], 2'b00};
        end else begin : g_pa_32
            assign HADDR = {instr_addr_i[PA_BITS-1:2], 2'b00};
        end
    endgenerate

    // A transfer accepted in a ready cycle is in its data phase next cycle.
    // While HREADY is low the current data phase continues.
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            dphase_q <= 1'b0;
        else if (HREADY)
            dphase_q <= instr_req_i & ~hold_i;
    end

endmodule
