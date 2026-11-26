// neumann_soc_synth.f - SYNTHESIS file list (paths relative to neumann_soc/).
// = neumann_soc.f with 3 files swapped for handover/rtl_synth/ versions:
//   rom1p1r (boot ROM contents), ram1p1rwbe (SRAM macros), cluster_clock_gating (ICG).
// Defines for tape-out: +define+NEUMANN_GF28_SRAM +define+NEUMANN_GF28_ICG
// Top module: neumann_soc   (rtl/top/neumann_soc.sv), default parameters.
+incdir+config
+incdir+rtl/peripherals/config/shared
+incdir+rtl/core

// ---- uncore IP subset (package first)
rtl/peripherals/src/cvw.sv
rtl/peripherals/src/generic/mux.sv
rtl/peripherals/src/generic/flop/flop.sv
rtl/peripherals/src/generic/flop/flopen.sv
rtl/peripherals/src/generic/flop/flopenl.sv
rtl/peripherals/src/generic/flop/flopenr.sv
rtl/peripherals/src/generic/flop/flopr.sv
rtl/peripherals/src/generic/flop/synchronizer.sv
handover/rtl_synth/ram1p1rwbe_gf28.sv
handover/rtl_synth/rom1p1r_bootrom.sv
rtl/peripherals/src/mmu/adrdec.sv
rtl/peripherals/src/mmu/adrdecs.sv
rtl/peripherals/src/uncore/ahbapbbridge.sv
rtl/peripherals/src/uncore/clint_apb.sv
rtl/peripherals/src/uncore/plic_apb.sv
rtl/peripherals/src/uncore/uartPC16550D.sv
rtl/peripherals/src/uncore/uart_apb.sv
rtl/peripherals/src/uncore/gpio_apb.sv
rtl/peripherals/src/uncore/spi_fifo.sv
rtl/peripherals/src/uncore/spi_controller.sv
rtl/peripherals/src/uncore/spi_apb.sv
rtl/peripherals/src/uncore/pwm_apb.sv
rtl/peripherals/src/uncore/rom_ahb.sv
rtl/peripherals/src/uncore/ram_ahb.sv
rtl/peripherals/src/uncore/uncore.sv
// (rtl/peripherals/src/generic/mem/*_64x*.sv, *_128x*.sv: SRAM-macro wrappers, only
//  needed with USE_SRAM = 1; not in this list)

// ---- neumann core
handover/rtl_synth/cluster_clock_gating_gf28.sv
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
