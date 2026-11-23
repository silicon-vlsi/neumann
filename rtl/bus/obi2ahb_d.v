// =============================================================================
// obi2ahb_d.v
// neumann data port (OBI-style) -> AHB-Lite master, ebu3 master 1 (LSU) or 2 (DBG)
//
// Part of neumann_soc (neumann core on Wally uncore).
//
// Core side (data port of rv32i_core):
//   data_req_o / data_gnt_i / data_rvalid_i / data_we_o / data_be_o[3:0] /
//   data_addr_o / data_wdata_o / data_rdata_i / data_err_i
//   - one transfer outstanding at most; misaligned access = two transfers,
//     the 2nd req comes in the same cycle as rvalid of the 1st
//   - addr is the byte address from the ALU (not aligned); be tells the bytes
//   - wdata is already rotated to the byte lanes
//
// AHB side (to ebu3 LSUH* or DBGH* inputs):
//   Same convention as obi2ahb_i:
//     HTRANS = NONSEQ only when req & ~hold_i & HREADY.
//   hold_i = ~HGRANT from ebu3 (LSU waits while the debug unit has the bus;
//   the debug master is never held). Tie to 0 if this is the only master.
//
//   gnt    = req & HREADY & ~hold_i
//   rvalid = data phase pending & HREADY
//   err    = rvalid & HRESP   (AHB ERROR is a 2-cycle response; the 2nd cycle
//                              has HREADY=1, HRESP=1 -> err with rvalid)
//
//   HSIZE / HADDR[1:0] from be:
//     1111            -> word,     offset 0
//     0011 / 1100     -> halfword, offset 0 / 2
//     0001/0010/0100/1000 -> byte, offset 0/1/2/3
//     other (1110, 0111, 0110: parts of misaligned accesses)
//                     -> word, offset 0, HWSTRB = be picks the bytes
//   Note: for those "other" patterns a read is a full-word read. Fine for
//   RAM/ROM; misaligned loads from peripheral registers are a software bug.
//
//   HWDATA lanes: for byte and halfword stores the data is copied to all lanes
//   (byte -> 4 copies, halfword -> 2 copies), like the Wally LSU does. Wally APB
//   peripherals with byte registers (uart_apb) read PWDATA[7:0] only, whatever
//   the address; RAM uses HWSTRB, so it does not care.
//
//   HWDATA and HWSTRB are data-phase signals (Wally ram_ahb / ahbapbbridge use
//   HWSTRB in the data phase). Both are captured at gnt and held through our
//   data phase. HWSTRB = 0 on reads and outside our data phase.
// =============================================================================
module obi2ahb_d #(
    parameter PA_BITS = 32
) (
    input                    HCLK,
    input                    HRESETn,

    // ---- OBI-style slave, from core data port or UART debug unit ----
    input                    data_req_i,
    /* verilator lint_off UNUSEDSIGNAL */  // [1:0] unused: offset comes from be
    input      [31:0]        data_addr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    input                    data_we_i,
    input      [3:0]         data_be_i,
    input      [31:0]        data_wdata_i,
    output                   data_gnt_o,
    output                   data_rvalid_o,
    output     [31:0]        data_rdata_o,
    output                   data_err_o,

    // ---- AHB-Lite master, to EBU LSU port ----
    output     [1:0]         HTRANS,
    output                   HWRITE,
    output reg [2:0]         HSIZE,
    output     [2:0]         HBURST,
    output     [PA_BITS-1:0] HADDR,
    output reg [31:0]        HWDATA,
    output reg [3:0]         HWSTRB,
    input                    HREADY,     // LSUHREADY from EBU
    input      [31:0]        HRDATA,
    input                    HRESP,
    input                    hold_i      // 1: not granted (EBU HGRANT = 0), do not start a transfer
);

    reg       dphase_q;   // 1: our data phase is on the bus
    reg [1:0] offset;     // HADDR[1:0]

    assign data_gnt_o    = data_req_i & HREADY & ~hold_i;
    assign data_rvalid_o = dphase_q & HREADY;
    assign data_rdata_o  = HRDATA;
    assign data_err_o    = dphase_q & HREADY & HRESP;

    assign HTRANS = data_gnt_o ? 2'b10 : 2'b00;    // NONSEQ or IDLE
    assign HWRITE = data_we_i;
    assign HBURST = 3'b000;                        // SINGLE

    // size and low address bits from byte enables
    always @(*) begin
        case (data_be_i)
            4'b0001: begin HSIZE = 3'b000; offset = 2'd0; end
            4'b0010: begin HSIZE = 3'b000; offset = 2'd1; end
            4'b0100: begin HSIZE = 3'b000; offset = 2'd2; end
            4'b1000: begin HSIZE = 3'b000; offset = 2'd3; end
            4'b0011: begin HSIZE = 3'b001; offset = 2'd0; end
            4'b1100: begin HSIZE = 3'b001; offset = 2'd2; end
            default: begin HSIZE = 3'b010; offset = 2'd0; end  // 1111 and partial words
        endcase
    end

    // store data copied to all lanes for byte / halfword (see header)
    reg [31:0] wdata_rep;
    always @(*) begin
        case (HSIZE)
            3'b000:  case (offset)
                         2'd0: wdata_rep = {4{data_wdata_i[ 7: 0]}};
                         2'd1: wdata_rep = {4{data_wdata_i[15: 8]}};
                         2'd2: wdata_rep = {4{data_wdata_i[23:16]}};
                         default: wdata_rep = {4{data_wdata_i[31:24]}};
                     endcase
            3'b001:  wdata_rep = offset[1] ? {2{data_wdata_i[31:16]}} : {2{data_wdata_i[15:0]}};
            default: wdata_rep = data_wdata_i;
        endcase
    end

    generate
        if (PA_BITS > 32) begin : g_pa_wide
            assign HADDR = {{(PA_BITS-32){1'b0}}, data_addr_i[31:2], offset};
        end else begin : g_pa_32
            assign HADDR = {data_addr_i[PA_BITS-1:2], offset};
        end
    endgenerate

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            dphase_q <= 1'b0;
            HWDATA   <= 32'b0;
            HWSTRB   <= 4'b0;
        end else begin
            if (HREADY)
                dphase_q <= data_req_i & ~hold_i;
            if (data_gnt_o) begin
                HWDATA <= wdata_rep;
                HWSTRB <= data_we_i ? data_be_i : 4'b0000;
            end else if (HREADY) begin
                HWSTRB <= 4'b0000;   // our data phase is over: no stale strobes in IFU data phases
            end
        end
    end

endmodule
