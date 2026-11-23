// Standard 8N1 UART receiver. CLKS_PER_BIT = clk_freq/baud.
module uart_rx #(parameter CLKS_PER_BIT=868)(
  input clk, input rst_n,
  input  rx_i,               // serial in
  output reg       valid_o,  // 1-cycle strobe when byte ready
  output reg [7:0] data_o
);
  localparam S_IDLE=3'd0,S_START=3'd1,S_DATA=3'd2,S_STOP=3'd3;
  // bit-time counts as unsigned 16-bit constants (CLKS_PER_BIT must be 2..65535)
  localparam [15:0] BIT_END = CLKS_PER_BIT - 1;
  localparam [15:0] BIT_MID = (CLKS_PER_BIT - 1) / 2;
  reg [2:0] st;
  reg [15:0] cnt;
  reg [2:0] bit_idx;
  reg rx_d, rx_q;
  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin rx_d<=1'b1; rx_q<=1'b1; end
    else begin rx_d<=rx_i; rx_q<=rx_d; end   // 2FF sync
  end
  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      st<=S_IDLE; cnt<=0; bit_idx<=0; valid_o<=0; data_o<=0;
    end else begin
      valid_o<=1'b0;
      case(st)
        S_IDLE: begin cnt<=0; bit_idx<=0; if(~rx_q) st<=S_START; end
        S_START: begin
          if(cnt==BIT_MID) begin
            if(~rx_q) begin cnt<=0; st<=S_DATA; end else st<=S_IDLE;
          end else cnt<=cnt+1;
        end
        S_DATA: begin
          if(cnt<BIT_END) cnt<=cnt+1;
          else begin
            cnt<=0; data_o[bit_idx]<=rx_q;
            if(bit_idx==3'd7) begin bit_idx<=0; st<=S_STOP; end
            else bit_idx<=bit_idx+1;
          end
        end
        S_STOP: begin
          if(cnt<BIT_END) cnt<=cnt+1;
          else begin cnt<=0; valid_o<=1'b1; st<=S_IDLE; end
        end
        default: st<=S_IDLE;
      endcase
    end
  end
endmodule
