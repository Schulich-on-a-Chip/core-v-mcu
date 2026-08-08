# Timing constraints for the complete two-input-clock SPI/QSPI master macro.
# Both top-level clock inputs target 20 MHz and are asynchronous to one another.
# The externally visible SPI clock is generated inside udma_clkgen from
# periph_clk_i; SPI pin delays are conservatively referenced to periph_clk.

current_design udma_spim_top

create_clock -name sys_clk -period 50.0 [get_ports sys_clk_i]
create_clock -name periph_clk -period 50.0 [get_ports periph_clk_i]

set_clock_groups -asynchronous \
  -group [get_clocks sys_clk] \
  -group [get_clocks periph_clk]

set_clock_transition 0.15 [get_clocks {sys_clk periph_clk}]
set_clock_uncertainty 0.25 [get_clocks {sys_clk periph_clk}]

if {[info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) == 0} {
  set_propagated_clock [get_clocks {sys_clk periph_clk}]
}

set_case_analysis 0 [get_ports {dft_test_mode_i dft_cg_enable_i}]

set sys_inputs [get_ports {
  spi_event_i*
  cfg_data_i*
  cfg_addr_i*
  cfg_valid_i
  cfg_rwn_i
  cfg_cmd_en_i
  cfg_cmd_pending_i
  cfg_cmd_curr_addr_i*
  cfg_cmd_bytes_left_i*
  cfg_rx_en_i
  cfg_rx_pending_i
  cfg_rx_curr_addr_i*
  cfg_rx_bytes_left_i*
  cfg_tx_en_i
  cfg_tx_pending_i
  cfg_tx_curr_addr_i*
  cfg_tx_bytes_left_i*
  cmd_gnt_i
  cmd_i*
  cmd_valid_i
  data_tx_gnt_i
  data_tx_i*
  data_tx_valid_i
  data_rx_ready_i
}]

set sys_outputs [get_ports {
  spi_eot_o
  cfg_ready_o
  cfg_data_o*
  cfg_cmd_startaddr_o*
  cfg_cmd_size_o*
  cfg_cmd_continuous_o
  cfg_cmd_en_o
  cfg_cmd_clr_o
  cfg_rx_startaddr_o*
  cfg_rx_size_o*
  cfg_rx_continuous_o
  cfg_rx_en_o
  cfg_rx_clr_o
  cfg_tx_startaddr_o*
  cfg_tx_size_o*
  cfg_tx_continuous_o
  cfg_tx_en_o
  cfg_tx_clr_o
  cmd_req_o
  cmd_datasize_o*
  cmd_ready_o
  data_tx_req_o
  data_tx_datasize_o*
  data_tx_ready_o
  data_rx_datasize_o*
  data_rx_o*
  data_rx_valid_o
}]

set spi_inputs [get_ports {
  spi_sdi0_i
  spi_sdi1_i
  spi_sdi2_i
  spi_sdi3_i
}]

set spi_outputs [get_ports {
  spi_csn0_o
  spi_csn1_o
  spi_csn2_o
  spi_csn3_o
  spi_oe0_o
  spi_oe1_o
  spi_oe2_o
  spi_oe3_o
  spi_sdo0_o
  spi_sdo1_o
  spi_sdo2_o
  spi_sdo3_o
}]

set_input_delay 2.0 -clock sys_clk $sys_inputs
set_output_delay 2.0 -clock sys_clk $sys_outputs
set_input_delay 2.0 -clock periph_clk $spi_inputs
set_output_delay 2.0 -clock periph_clk $spi_outputs

# spi_clk_o is the source-synchronous clock sent with the SPI data, not data
# that must arrive before a later periph_clk edge. Its waveform is controlled
# by the runtime divider/bypass configuration and must not be analyzed as an
# ordinary output-data path.
set_false_path -to [get_ports spi_clk_o]

set_false_path -from [get_ports rstn_i]

set_load -pin_load 0.07291 [all_outputs]

set_driving_cell \
  -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 \
  -pin ZN \
  $sys_inputs

set_driving_cell \
  -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 \
  -pin ZN \
  [get_ports {spi_sdi0_i spi_sdi1_i spi_sdi2_i spi_sdi3_i rstn_i}]

set_driving_cell \
  -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4 \
  -pin ZN \
  [get_ports {sys_clk_i periph_clk_i}]

# The GF180 MCU 7-track 5 V slow-corner liberty file characterizes output
# transitions to 7 ns. A 0.90 pF design cap remains below the characterized
# 0.9639 pF limit of the clock buffer that previously triggered an artificial
# violation with the earlier 0.30 pF override.
set_max_transition 7.0 [current_design]
set_max_capacitance 0.9 [current_design]
set_max_fanout 10 [current_design]
