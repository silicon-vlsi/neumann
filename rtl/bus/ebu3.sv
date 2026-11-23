// =============================================================================
// ebu3.sv
// External bus unit for the neumann SoC: 3 AHB-Lite masters -> 1 AHB-Lite bus.
//
// Part of neumann_soc (neumann core on Wally uncore). Derived from the
// CORE-V-Wally EBU (cvw src/ebu/ebu.sv, ebufsmarb.sv, Apache-2.0 WITH SHL-2.1;
// not kept in uncore_ip/ here, see uncore_ip/VERSION.txt for the cvw commit):
// same bus-side ports and output mux, so it drops into the Wally uncore in
// place of `ebu`. The Wally files are not changed.
//
//   master 0  IFU  (obi2ahb_i, core instruction port)   lowest priority, default
//   master 1  LSU  (obi2ahb_d, core data port)
//   master 2  DBG  (obi2ahb_d, UART debug unit memory port)   highest priority
//
// Why not Wally's FSM: Wally's ebufsmarb saves the IFU address phase and
// replays it later (Save/Restore) because Wally's own IFU cannot wait for a
// grant. Our three bridges can wait: they start an address phase only when
// HGRANT = 1 (and HREADY = 1), and hold their OBI request otherwise. So the
// arbitration is the classic AHB HBUSREQ / HGRANT scheme:
//
//   HGRANT  : fixed priority DBG > LSU > IFU, from the OBI requests (comb.)
//   address : only the granted master can drive HTRANS != IDLE, so at most
//             one address phase is on the bus in any cycle; output mux
//             selects the granted master.
//   data    : HMASTER = owner of the data phase, registered when an address
//             phase is accepted (HREADY = 1). HWDATA / HWSTRB come from the
//             owner. HREADY / HRESP / HRDATA go to all masters; each bridge
//             only looks at them while it owns the data phase.
//
// Bridges drive HTRANS = NONSEQ only in the cycle the address is accepted
// (HTRANS = req & grant & HREADY), so no address is ever left waiting on the
// bus and the grant can change in any cycle without breaking the AHB rule
// "address/control stable while HREADY = 0".
//
// No starvation in practice: the debug unit is UART paced (one transfer per
// command), and the core cannot keep the LSU busy without new instructions,
// so the IFU always gets slots.
//
// HMASTER state machine (2 bits):  NONE -> {IFU, LSU, DBG} on an accepted
// address phase; held while HREADY = 0; on HREADY = 1 it moves to the owner
// of the next accepted address phase, or NONE if the bus is idle.
// =============================================================================
module ebu3 #(
  parameter int PA_BITS = 32
) (
  input  logic               HCLK,
  input  logic               HRESETn,

  // ---- master 0: IFU (read only) ----
  /* verilator lint_off UNUSEDSIGNAL */   // lowest priority: its request does not affect any grant
  input  logic               IFUHBUSREQ,
  /* verilator lint_on UNUSEDSIGNAL */
  output logic               IFUHGRANT,
  input  logic [1:0]         IFUHTRANS,
  input  logic [2:0]         IFUHSIZE,
  input  logic [2:0]         IFUHBURST,
  input  logic [PA_BITS-1:0] IFUHADDR,

  // ---- master 1: LSU ----
  input  logic               LSUHBUSREQ,
  output logic               LSUHGRANT,
  input  logic [1:0]         LSUHTRANS,
  input  logic               LSUHWRITE,
  input  logic [2:0]         LSUHSIZE,
  input  logic [2:0]         LSUHBURST,
  input  logic [PA_BITS-1:0] LSUHADDR,
  input  logic [31:0]        LSUHWDATA,
  input  logic [3:0]         LSUHWSTRB,

  // ---- master 2: DBG ----
  input  logic               DBGHBUSREQ,
  output logic               DBGHGRANT,
  input  logic [1:0]         DBGHTRANS,
  input  logic               DBGHWRITE,
  input  logic [2:0]         DBGHSIZE,
  input  logic [2:0]         DBGHBURST,
  input  logic [PA_BITS-1:0] DBGHADDR,
  input  logic [31:0]        DBGHWDATA,
  input  logic [3:0]         DBGHWSTRB,

  // ---- AHB-Lite bus (to uncore) ----
  input  logic               HREADY,
  output logic [PA_BITS-1:0] HADDR,
  output logic [31:0]        HWDATA,
  output logic [3:0]         HWSTRB,
  output logic               HWRITE,
  output logic [2:0]         HSIZE,
  output logic [2:0]         HBURST,
  output logic [3:0]         HPROT,
  output logic [1:0]         HTRANS,
  output logic               HMASTLOCK,
  output logic [1:0]         HMASTER     // data-phase owner (debug / trace)
);

  localparam logic [1:0] M_NONE = 2'd0, M_IFU = 2'd1, M_LSU = 2'd2, M_DBG = 2'd3;

  // ---------------------------------------------------------------- grant
  assign DBGHGRANT = 1'b1;                         // top priority: never blocked
  assign LSUHGRANT = ~DBGHBUSREQ;
  assign IFUHGRANT = ~DBGHBUSREQ & ~LSUHBUSREQ;    // default master

  // address-phase select (one-hot by construction)
  logic sel_dbg, sel_lsu, sel_ifu;
  assign sel_dbg = DBGHBUSREQ;
  assign sel_lsu = ~DBGHBUSREQ & LSUHBUSREQ;
  assign sel_ifu = ~DBGHBUSREQ & ~LSUHBUSREQ;

  // ---------------------------------------------------------------- address phase mux
  always_comb begin
    if (sel_dbg) begin
      HADDR = DBGHADDR; HSIZE = DBGHSIZE; HBURST = DBGHBURST; HTRANS = DBGHTRANS; HWRITE = DBGHWRITE;
    end else if (sel_lsu) begin
      HADDR = LSUHADDR; HSIZE = LSUHSIZE; HBURST = LSUHBURST; HTRANS = LSUHTRANS; HWRITE = LSUHWRITE;
    end else begin
      HADDR = IFUHADDR; HSIZE = IFUHSIZE; HBURST = IFUHBURST; HTRANS = IFUHTRANS; HWRITE = 1'b0;
    end
  end
  assign HPROT     = {3'b001, ~sel_ifu};   // privileged; bit 0: data access (not opcode fetch)
  assign HMASTLOCK = 1'b0;

  // ---------------------------------------------------------------- data phase owner
  logic [1:0] owner_q, owner_n;
  always_comb begin
    owner_n = owner_q;
    if (HREADY) begin
      if (HTRANS != 2'b00) owner_n = sel_dbg ? M_DBG : sel_lsu ? M_LSU : M_IFU;
      else                 owner_n = M_NONE;
    end
  end
  always_ff @(posedge HCLK or negedge HRESETn)
    if (!HRESETn) owner_q <= M_NONE;
    else          owner_q <= owner_n;
  assign HMASTER = owner_q;

  // ---------------------------------------------------------------- data phase mux
  assign HWDATA = (owner_q == M_DBG) ? DBGHWDATA : LSUHWDATA;
  assign HWSTRB = (owner_q == M_DBG) ? DBGHWSTRB :
                  (owner_q == M_LSU) ? LSUHWSTRB : 4'b0000;

endmodule
