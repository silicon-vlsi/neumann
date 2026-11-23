// neumann_soc file list. Paths are relative to the neumann_soc/ folder:
// run the simulator / synthesis tool from there, or prefix the paths.
// Top module: neumann_soc   (rtl/top/neumann_soc.sv)
+incdir+config
+incdir+uncore_ip/config/shared
+incdir+rtl/core

// ---- CORE-V-Wally subset (package first)
uncore_ip/src/cvw.sv
uncore_ip/src/generic/mux.sv
uncore_ip/src/generic/flop/flop.sv
uncore_ip/src/generic/flop/flopen.sv
uncore_ip/src/generic/flop/flopenl.sv
uncore_ip/src/generic/flop/flopenr.sv
uncore_ip/src/generic/flop/flopr.sv
uncore_ip/src/generic/flop/synchronizer.sv
uncore_ip/src/generic/mem/ram1p1rwbe.sv
uncore_ip/src/generic/mem/rom1p1r.sv
uncore_ip/src/mmu/adrdec.sv
uncore_ip/src/mmu/adrdecs.sv
uncore_ip/src/uncore/ahbapbbridge.sv
uncore_ip/src/uncore/clint_apb.sv
uncore_ip/src/uncore/plic_apb.sv
uncore_ip/src/uncore/uartPC16550D.sv
uncore_ip/src/uncore/uart_apb.sv
uncore_ip/src/uncore/gpio_apb.sv
uncore_ip/src/uncore/spi_fifo.sv
uncore_ip/src/uncore/spi_controller.sv
uncore_ip/src/uncore/spi_apb.sv
uncore_ip/src/uncore/pwm_apb.sv
uncore_ip/src/uncore/rom_ahb.sv
uncore_ip/src/uncore/ram_ahb.sv
uncore_ip/src/uncore/uncore.sv
// (uncore_ip/src/generic/mem/*_64x*.sv, *_128x*.sv: SRAM-macro wrappers, only
//  needed with USE_SRAM = 1; not in this list)

// ---- neumann core
rtl/core/cluster_clock_gating.sv
rtl/core/rv32i_alu.v
rtl/core/rv32i_compressed_decoder.v
rtl/core/rv32i_controller.v
rtl/core/rv32i_cs_registers.v
rtl/core/rv32i_debug_unit.v
rtl/core/rv32i_decoder.v
rtl/core/rv32i_ex_block.v
rtl/core/rv32i_fetch_fifo.v
rtl/core/rv32i_id_stage.v
rtl/core/rv32i_if_stage.v
rtl/core/rv32i_int_controller.v
rtl/core/rv32i_load_store_unit.v
rtl/core/rv32i_prefetch_buffer.v
rtl/core/rv32i_register_file.v
rtl/core/rv32i_core.v

// ---- UART debug unit
rtl/debug/uart_rx.v
rtl/debug/uart_tx.v
rtl/debug/uart_debug_unit.v

// ---- SoC glue + top
rtl/sys/rst_sync.v
rtl/sys/irq_enc.v
rtl/bus/ebu3.sv
rtl/bus/obi2ahb_i.v
rtl/bus/obi2ahb_d.v
rtl/top/neumann_soc.sv
