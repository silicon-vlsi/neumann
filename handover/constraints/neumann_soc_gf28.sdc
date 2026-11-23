# neumann_soc_gf28.sdc - TEMPLATE for GF 28nm. PD team: fill the <...> items.
# Single clock domain. All verification ran at 100 MHz (10 ns).
# NOTE: debug UART baud = clk / DBG_CLKS_PER_BIT (RTL parameter, 868 -> 115200 @ 100 MHz).
#       If the sign-off clock is not 100 MHz, tell us: DBG_CLKS_PER_BIT must change.

set CLK_PERIOD 10.0
create_clock -name clk -period $CLK_PERIOD [get_ports clk_i]
set_clock_uncertainty -setup <0.25> [get_clocks clk]
set_clock_uncertainty -hold  <0.05> [get_clocks clk]
set_clock_transition <0.10> [get_clocks clk]

# Mission mode: test_en_i = 0 (clock gates normal, reset synchroniser in use)
set_case_analysis 0 [get_ports test_en_i]

# Inputs / outputs (board timing unknown: 20% of period as budget)
set IO_DLY [expr 0.2 * $CLK_PERIOD]
set_input_delay  $IO_DLY -clock clk [remove_from_collection [all_inputs] [get_ports clk_i]]
set_output_delay $IO_DLY -clock clk [all_outputs]
set_driving_cell -lib_cell <GF28_BUF_X2> [remove_from_collection [all_inputs] [get_ports clk_i]]
set_load <0.02> [all_outputs]

# Asynchronous inputs: each goes through a 2-FF synchroniser in the RTL
set_false_path -from [get_ports rst_ni]        ;# -> rtl/sys/rst_sync.v
set_false_path -from [get_ports dbg_rx_i]      ;# -> rtl/debug/uart_rx.v 2FF
set_false_path -from [get_ports uart_rx_i]     ;# -> uartPC16550D synchronizer
set_false_path -from [get_ports gpio_i*]       ;# -> gpio_apb input sync (gpio_i[31:30] = boot pins)
set_false_path -from [get_ports fetch_enable_i];# static strap
set_false_path -from [get_ports test_en_i]     ;# static (DFT)

# SPI / SDC: sck is generated from clk by a counter in logic (registered output),
# miso sampled by clk -> normal IO constraints above are enough.

# Clock gating: 32 ICG cells (rtl_synth/cluster_clock_gating_gf28.sv). Library ICG
# cells carry their own gating checks; nothing else needed.
