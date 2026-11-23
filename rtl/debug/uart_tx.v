// Standard 8N1 UART transmitter.
module uart_tx #(parameter CLKS_PER_BIT=868)(
  input clk, input rst_n,
  input        send_i,        // 1-cycle strobe to start
  input  [7:0] data_i,
  output reg   tx_o,          // serial out (idle high)
  output reg   busy_o,
  output reg   done_o         // 1-cycle strobe at end
);
  localparam S_IDLE=3'd0,S_START=3'd1,S_DATA=3'd2,S_STOP=3'd3;
  // bit-time counts as unsigned 16-bit constants (CLKS_PER_BIT must be 2..65535)
  localparam [15:0] BIT_END = CLKS_PER_BIT - 1;
  reg [2:0] st; reg [15:0] cnt; reg [2:0] bit_idx; reg [7:0] shreg;
  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      st<=S_IDLE; tx_o<=1'b1; busy_o<=0; done_o<=0; cnt<=0; bit_idx<=0; shreg<=0;
    end else begin
      done_o<=1'b0;
      case(st)
        S_IDLE: begin tx_o<=1'b1; busy_o<=0; cnt<=0; bit_idx<=0;
          if(send_i) begin shreg<=data_i; busy_o<=1; st<=S_START; end
        end
        S_START: begin tx_o<=1'b0;
          if(cnt<BIT_END) cnt<=cnt+1; else begin cnt<=0; st<=S_DATA; end
        end
        S_DATA: begin tx_o<=shreg[bit_idx];
          if(cnt<BIT_END) cnt<=cnt+1;
          else begin cnt<=0;
            if(bit_idx==3'd7) begin bit_idx<=0; st<=S_STOP; end
            else bit_idx<=bit_idx+1;
          end
        end
        S_STOP: begin tx_o<=1'b1;
          if(cnt<BIT_END) cnt<=cnt+1;
          else begin cnt<=0; done_o<=1'b1; busy_o<=0; st<=S_IDLE; end
        end
        default: st<=S_IDLE;
      endcase
    end
  end
endmodule
