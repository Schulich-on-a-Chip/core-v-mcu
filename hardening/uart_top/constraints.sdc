# Initial experimental constraints for the complete two-clock UART macro.
# Both domains currently target 50 MHz. They are asynchronous to one another,
# and the RTL contains dedicated FIFOs and synchronizers for domain crossings.

current_design udma_uart_top

create_clock -name sys_clk -period 20.0 [get_ports sys_clk_i]
create_clock -name periph_clk -period 20.0 [get_ports periph_clk_i]

set_clock_groups -asynchronous \
  -group [get_clocks sys_clk] \
  -group [get_clocks periph_clk]

set_clock_transition 0.15 [get_clocks {sys_clk periph_clk}]
set_clock_uncertainty 0.25 [get_clocks {sys_clk periph_clk}]

if {[info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) == 0} {
  set_propagated_clock [get_clocks {sys_clk periph_clk}]
}

set sys_inputs [get_ports {
  cfg_data_i*
  cfg_addr_i*
  cfg_valid_i
  cfg_rwn_i
  cfg_rx_en_i
  cfg_rx_pending_i
  cfg_rx_curr_addr_i*
  cfg_rx_bytes_left_i*
  cfg_tx_en_i
  cfg_tx_pending_i
  cfg_tx_curr_addr_i*
  cfg_tx_bytes_left_i*
  data_tx_gnt_i
  data_tx_i*
  data_tx_valid_i
  data_rx_ready_i
}]

set sys_outputs [get_ports {
  rx_char_event_o
  err_event_o
  cfg_ready_o
  cfg_data_o*
  cfg_rx_startaddr_o*
  cfg_rx_size_o*
  cfg_rx_datasize_o*
  cfg_rx_continuous_o
  cfg_rx_en_o
  cfg_rx_clr_o
  cfg_tx_startaddr_o*
  cfg_tx_size_o*
  cfg_tx_datasize_o*
  cfg_tx_continuous_o
  cfg_tx_en_o
  cfg_tx_clr_o
  data_tx_req_o
  data_tx_datasize_o*
  data_tx_ready_o
  data_rx_datasize_o*
  data_rx_o*
  data_rx_valid_o
}]

set_input_delay 4.0 -clock sys_clk $sys_inputs
set_output_delay 4.0 -clock sys_clk $sys_outputs
set_input_delay 4.0 -clock periph_clk [get_ports uart_rx_i]
set_output_delay 4.0 -clock periph_clk [get_ports uart_tx_o]

set_false_path -from [get_ports rstn_i]

set_load -pin_load 0.07291 [all_outputs]

set_driving_cell \
  -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 \
  -pin ZN \
  $sys_inputs

set_driving_cell \
  -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 \
  -pin ZN \
  [get_ports {uart_rx_i rstn_i}]

set_driving_cell \
  -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4 \
  -pin ZN \
  [get_ports {sys_clk_i periph_clk_i}]

set_max_transition 3.0 [current_design]
set_max_capacitance 0.2 [current_design]
set_max_fanout 10 [current_design]
