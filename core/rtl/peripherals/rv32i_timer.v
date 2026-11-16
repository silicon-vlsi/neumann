// ============================================================
// rv32i_timer : RISC-V machine timer (mtime / mtimecmp), CLINT layout
//
// Data-bus slave with the same handshake as data_mem:
//   combinational grant, rvalid (and read data) one cycle later,
//   rvalid also returned for writes.
//
// Register map (byte offsets inside the 64 KB timer window,
// same offsets as the SiFive CLINT, so the stock FreeRTOS RISC-V
// port works with configMTIME_BASE_ADDRESS    = BASE + 0xBFF8 and
//                    configMTIMECMP_BASE_ADDRESS = BASE + 0x4000):
//   0x4000  mtimecmp[31:0]   R/W
//   0x4004  mtimecmp[63:32]  R/W
//   0xBFF8  mtime[31:0]      R/W
//   0xBFFC  mtime[63:32]     R/W
//   other offsets read 0, writes are ignored
//
// mtime counts up by one every PRESCALE clock cycles.
// irq_o = (mtime >= mtimecmp), a level: it stays high until software
// writes a larger mtimecmp. mtimecmp resets to all ones, so there is
// no interrupt until software programs it.
//
// Connect clk to the free-running (ungated) SoC clock: the timer has
// to keep counting while the core sleeps in WFI.
// ============================================================
module rv32i_timer #(
  parameter PRESCALE = 1          // mtime increments every PRESCALE clk cycles (>= 1)
)(
  input             clk,
  input             rst_n,
  // data-bus slave (req_i only while the address is inside the timer window)
  input             req_i,
  output            gnt_o,
  output reg        rvalid_o,
  input             we_i,
  input      [3:0]  be_i,
  input      [15:2] addr_i,        // word address inside the 64 KB window
  input      [31:0] wdata_i,
  output reg [31:0] rdata_o,
  // interrupt to the core (irq_i, id 7)
  output            irq_o
);
  localparam [15:0] OFF_CMP_LO  = 16'h4000;
  localparam [15:0] OFF_CMP_HI  = 16'h4004;
  localparam [15:0] OFF_TIME_LO = 16'hBFF8;
  localparam [15:0] OFF_TIME_HI = 16'hBFFC;
  localparam        PW          = (PRESCALE > 1) ? $clog2(PRESCALE) : 1;

  reg [63:0] mtime;
  reg [63:0] mtimecmp;
  reg [PW-1:0] psc_cnt;

  wire [15:0] word_addr = {addr_i, 2'b00};
  wire        wr        = req_i & we_i;
  wire        tick      = (PRESCALE <= 1) ? 1'b1 : (psc_cnt == PRESCALE - 1);

  // byte-enable merge of a 32-bit write into one half of a 64-bit register
  function [31:0] merge;
    input [31:0] old;
    input [31:0] new_data;
    input [3:0]  be;
    begin
      merge[ 7: 0] = be[0] ? new_data[ 7: 0] : old[ 7: 0];
      merge[15: 8] = be[1] ? new_data[15: 8] : old[15: 8];
      merge[23:16] = be[2] ? new_data[23:16] : old[23:16];
      merge[31:24] = be[3] ? new_data[31:24] : old[31:24];
    end
  endfunction

  assign gnt_o = req_i;
  assign irq_o = (mtime >= mtimecmp);

  // prescaler
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)    psc_cnt <= {PW{1'b0}};
    else if (tick) psc_cnt <= {PW{1'b0}};
    else           psc_cnt <= psc_cnt + 1'b1;
  end

  // mtime: a software write wins over the increment in the same cycle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      mtime <= 64'd0;
    else if (wr && word_addr == OFF_TIME_LO)
      mtime[31:0]  <= merge(mtime[31:0], wdata_i, be_i);
    else if (wr && word_addr == OFF_TIME_HI)
      mtime[63:32] <= merge(mtime[63:32], wdata_i, be_i);
    else if (tick)
      mtime <= mtime + 64'd1;
  end

  // mtimecmp
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      mtimecmp <= {64{1'b1}};
    else if (wr && word_addr == OFF_CMP_LO)
      mtimecmp[31:0]  <= merge(mtimecmp[31:0], wdata_i, be_i);
    else if (wr && word_addr == OFF_CMP_HI)
      mtimecmp[63:32] <= merge(mtimecmp[63:32], wdata_i, be_i);
  end

  // read data and rvalid, one cycle after the grant
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rvalid_o <= 1'b0;
      rdata_o  <= 32'h0;
    end else begin
      rvalid_o <= req_i;
      if (req_i && !we_i) begin
        case (word_addr)
          OFF_CMP_LO:  rdata_o <= mtimecmp[31:0];
          OFF_CMP_HI:  rdata_o <= mtimecmp[63:32];
          OFF_TIME_LO: rdata_o <= mtime[31:0];
          OFF_TIME_HI: rdata_o <= mtime[63:32];
          default:     rdata_o <= 32'h0;
        endcase
      end
    end
  end
endmodule
