// =============================================================================
// rst_sync.v
// Reset synchronizer: asynchronous assert, synchronous de-assert (2 flops).
// rst_ni from the pad goes low at any time -> rst_no goes low at once;
// rst_ni goes high -> rst_no goes high after 2 rising edges of clk_i.
// test_mode_i = 1 bypasses the flops so DFT/scan controls reset directly.
//
// Part of neumann_soc (neumann core on Wally uncore).
// =============================================================================
module rst_sync (
    input  clk_i,
    input  rst_ni,
    input  test_mode_i,
    output rst_no
);
    reg [1:0] sync_q;
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) sync_q <= 2'b00;
        else         sync_q <= {sync_q[0], 1'b1};
    end
    assign rst_no = test_mode_i ? rst_ni : sync_q[1];
endmodule
