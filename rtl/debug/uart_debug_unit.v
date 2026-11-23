// ============================================================
// uart_debug_unit
// Host <-> serial debug bridge for rv32i_core.
//
// Protocol (host -> unit).  All multi-byte fields are LSB-first.
//   0x01                          HALT           -> 0x90
//   0x02                          RESUME         -> 0x90
//   0x03                          STEP (1 instr) -> 0x90
//   0x04                          STATUS         -> 1 byte (bit0 = halted)
//   0x10 <reg>                    READ  GPR      -> 4 bytes
//   0x11 <reg> <d0..d3>           WRITE GPR      -> 0x90
//   0x20 <csrL> <csrH>            READ  CSR      -> 4 bytes
//   0x21 <csrL><csrH> <d0..d3>    WRITE CSR      -> 0x90
//   0x30                          READ PC        -> 8 bytes (NPC then PPC)
//   0x40 <a0..a3>                 READ  MEM      -> 4 bytes
//   0x41 <a0..a3> <d0..d3>        WRITE MEM      -> 0x90
//
// Reg/CSR/PC reads require the core to be halted first (send HALT).
// ============================================================
module uart_debug_unit #(
  parameter CLKS_PER_BIT = 868      // 100 MHz / 115200
)(
  input  clk,
  input  rst_n,
  // serial
  input  rx_i,
  output tx_o,
  // core debug bus (to rv32i_core debug_* ports)
  output reg        dbg_req_o,
  input             dbg_gnt_i,
  input             dbg_rvalid_i,
  output reg [14:0] dbg_addr_o,
  output reg        dbg_we_o,
  output reg [31:0] dbg_wdata_o,
  input      [31:0] dbg_rdata_i,
  // data-memory master (muxed onto dmem in the SoC)
  output reg        mem_req_o,
  input             mem_gnt_i,
  input             mem_rvalid_i,
  output reg        mem_we_o,
  output reg [3:0]  mem_be_o,
  output reg [31:0] mem_addr_o,
  output reg [31:0] mem_wdata_o,
  input      [31:0] mem_rdata_i
);
  // ---- commands ----
  localparam C_HALT=8'h01, C_RES=8'h02, C_STEP=8'h03, C_STAT=8'h04,
             C_RREG=8'h10, C_WREG=8'h11, C_RCSR=8'h20, C_WCSR=8'h21,
             C_RPC=8'h30,  C_RMEM=8'h40, C_WMEM=8'h41;
  localparam ACK=8'h90;

  // ---- UART instances ----
  wire       rx_valid; wire [7:0] rx_byte;
  reg        tx_send;  reg  [7:0] tx_byte; wire tx_busy, tx_done;
  uart_rx #(CLKS_PER_BIT) u_rx (.clk(clk),.rst_n(rst_n),.rx_i(rx_i),.valid_o(rx_valid),.data_o(rx_byte));
  uart_tx #(CLKS_PER_BIT) u_tx (.clk(clk),.rst_n(rst_n),.send_i(tx_send),.data_i(tx_byte),.tx_o(tx_o),.busy_o(tx_busy),.done_o(tx_done));

  // ---- receive buffer ----
  reg [7:0] cmd;
  reg [7:0] pay [0:7];
  reg [3:0] need, got;

  // ---- response buffer ----
  reg [7:0] resp [0:7];
  reg [3:0] resp_len, resp_idx;


  // ---- main FSM ----
  localparam [3:0] S_RXCMD=4'd0, S_RXPAY=4'd1, S_EXEC=4'd2,
                   S_BUS_REQ=4'd3, S_BUS_RV=4'd4,
                   S_MEM_REQ=4'd5, S_MEM_RV=4'd6,
                   S_BUILD=4'd7, S_TXSEND=4'd8, S_TXWAIT=4'd9;
  reg [3:0] st;
  reg [2:0] step;              // sub-step for multi-op commands (e.g. RPC)
  reg [31:0] rd0, rd1;         // captured read data

  // helper: decode payload length from command
  function [3:0] paylen(input [7:0] c);
    case(c)
      C_HALT,C_RES,C_STEP,C_STAT,C_RPC: paylen=4'd0;
      C_RREG:                            paylen=4'd1;
      C_WREG:                            paylen=4'd5;
      C_RCSR:                            paylen=4'd2;
      C_WCSR:                            paylen=4'd6;
      C_RMEM:                            paylen=4'd4;
      C_WMEM:                            paylen=4'd8;
      default:                           paylen=4'd0;
    endcase
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      st<=S_RXCMD; need<=0; got<=0; cmd<=0; step<=0;
      dbg_req_o<=0; dbg_addr_o<=0; dbg_we_o<=0; dbg_wdata_o<=0;
      mem_req_o<=0; mem_we_o<=0; mem_be_o<=0; mem_addr_o<=0; mem_wdata_o<=0;
      tx_send<=0; tx_byte<=0; resp_len<=0; resp_idx<=0; rd0<=0; rd1<=0;
    end else begin
      tx_send<=1'b0;
      case(st)
        // -------- receive --------
        S_RXCMD: begin
          step<=0; resp_idx<=0;
          if(rx_valid) begin
            cmd<=rx_byte; got<=0; need<=paylen(rx_byte);
            st<=(paylen(rx_byte)==0)?S_EXEC:S_RXPAY;
          end
        end
        S_RXPAY: begin
          if(rx_valid) begin
            pay[got[2:0]]<=rx_byte;
            if(got+1==need) st<=S_EXEC;
            got<=got+1;
          end
        end
        // -------- dispatch --------
        S_EXEC: begin
          case(cmd)
            C_HALT: begin dbg_addr_o<=15'h0000; dbg_we_o<=1'b1; dbg_wdata_o<=32'h0001_0000; st<=S_BUS_REQ; end
            C_RES:  begin dbg_addr_o<=15'h0000; dbg_we_o<=1'b1; dbg_wdata_o<=32'h0000_0000; st<=S_BUS_REQ; end
            C_STEP: begin dbg_addr_o<=15'h0000; dbg_we_o<=1'b1; dbg_wdata_o<=32'h0000_0001; st<=S_BUS_REQ; end
            C_STAT: begin dbg_addr_o<=15'h0000; dbg_we_o<=1'b0; st<=S_BUS_REQ; end
            C_RREG: begin dbg_addr_o<=15'h0400 | {8'd0, pay[0][4:0], 2'b00}; dbg_we_o<=1'b0; st<=S_BUS_REQ; end
            C_WREG: begin dbg_addr_o<=15'h0400 | {8'd0, pay[0][4:0], 2'b00}; dbg_we_o<=1'b1;
                          dbg_wdata_o<={pay[4],pay[3],pay[2],pay[1]}; st<=S_BUS_REQ; end
            C_RCSR: begin dbg_addr_o<=15'h4000 | {pay[1][4:0], pay[0], 2'b00}; dbg_we_o<=1'b0; st<=S_BUS_REQ; end
            C_WCSR: begin dbg_addr_o<=15'h4000 | {pay[1][4:0], pay[0], 2'b00}; dbg_we_o<=1'b1;
                          dbg_wdata_o<={pay[5],pay[4],pay[3],pay[2]}; st<=S_BUS_REQ; end
            C_RPC:  begin dbg_addr_o<=15'h2000; dbg_we_o<=1'b0; st<=S_BUS_REQ; end // NPC first
            C_RMEM: begin mem_addr_o<={pay[3],pay[2],pay[1],pay[0]}; mem_we_o<=1'b0; mem_be_o<=4'hF; st<=S_MEM_REQ; end
            C_WMEM: begin mem_addr_o<={pay[3],pay[2],pay[1],pay[0]}; mem_we_o<=1'b1; mem_be_o<=4'hF;
                          mem_wdata_o<={pay[7],pay[6],pay[5],pay[4]}; st<=S_MEM_REQ; end
            default: st<=S_RXCMD;
          endcase
        end
        // -------- core debug-bus transaction --------
        S_BUS_REQ: begin
          dbg_req_o<=1'b1;
          if(dbg_gnt_i) begin
            dbg_req_o<=1'b0;
            if(dbg_we_o) st<=S_BUILD;      // writes: done at grant
            else         st<=S_BUS_RV;     // reads: wait rvalid
          end
        end
        S_BUS_RV: begin
          if(dbg_rvalid_i) begin
            if(step==0) rd0<=dbg_rdata_i; else rd1<=dbg_rdata_i;
            // RPC needs a second read (PPC)
            if(cmd==C_RPC && step==0) begin
              step<=1; dbg_addr_o<=15'h2004; dbg_we_o<=1'b0; st<=S_BUS_REQ;
            end else st<=S_BUILD;
          end
        end
        // -------- memory master transaction --------
        S_MEM_REQ: begin
          mem_req_o<=1'b1;
          if(mem_gnt_i) begin mem_req_o<=1'b0; st<=S_MEM_RV; end
        end
        S_MEM_RV: begin
          if(mem_rvalid_i) begin rd0<=mem_rdata_i; st<=S_BUILD; end
        end
        // -------- assemble response --------
        S_BUILD: begin
          case(cmd)
            C_HALT,C_RES,C_STEP,C_WREG,C_WCSR,C_WMEM: begin resp[0]<=ACK; resp_len<=4'd1; end
            C_STAT: begin resp[0]<={7'b0, rd0[16]}; resp_len<=4'd1; end
            C_RREG,C_RCSR,C_RMEM: begin
              resp[0]<=rd0[7:0]; resp[1]<=rd0[15:8]; resp[2]<=rd0[23:16]; resp[3]<=rd0[31:24];
              resp_len<=4'd4;
            end
            C_RPC: begin
              resp[0]<=rd0[7:0]; resp[1]<=rd0[15:8]; resp[2]<=rd0[23:16]; resp[3]<=rd0[31:24];
              resp[4]<=rd1[7:0]; resp[5]<=rd1[15:8]; resp[6]<=rd1[23:16]; resp[7]<=rd1[31:24];
              resp_len<=4'd8;
            end
            default: begin resp[0]<=ACK; resp_len<=4'd1; end
          endcase
          resp_idx<=0; st<=S_TXSEND;
        end
        // -------- stream response --------
        S_TXSEND: begin
          if(!tx_busy) begin tx_byte<=resp[resp_idx[2:0]]; tx_send<=1'b1; st<=S_TXWAIT; end
        end
        S_TXWAIT: begin
          if(tx_done) begin
            if(resp_idx+1==resp_len) st<=S_RXCMD;
            else begin resp_idx<=resp_idx+1; st<=S_TXSEND; end
          end
        end
        default: st<=S_RXCMD;
      endcase
    end
  end
endmodule
