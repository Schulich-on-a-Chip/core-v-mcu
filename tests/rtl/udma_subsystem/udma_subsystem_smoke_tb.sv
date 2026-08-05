`timescale 1ns/1ps

`include "pulp_soc_defines.svh"
`include "pulp_peripheral_defines.svh"

module udma_subsystem_smoke_tb;

  localparam int L2_DATA_WIDTH = 32;
  localparam int APB_ADDR_WIDTH = 12;

  logic                         L2_ro_wen_o;
  logic                         L2_ro_req_o;
  logic                         L2_ro_gnt_i;
  logic [31:0]                  L2_ro_addr_o;
  logic [L2_DATA_WIDTH/8-1:0]   L2_ro_be_o;
  logic [L2_DATA_WIDTH-1:0]     L2_ro_wdata_o;
  logic                         L2_ro_rvalid_i;
  logic [L2_DATA_WIDTH-1:0]     L2_ro_rdata_i;

  logic                         L2_wo_wen_o;
  logic                         L2_wo_req_o;
  logic                         L2_wo_gnt_i;
  logic [31:0]                  L2_wo_addr_o;
  logic [L2_DATA_WIDTH-1:0]     L2_wo_wdata_o;
  logic [L2_DATA_WIDTH/8-1:0]   L2_wo_be_o;
  logic                         L2_wo_rvalid_i;
  logic [L2_DATA_WIDTH-1:0]     L2_wo_rdata_i;

  logic                         dft_test_mode_i;
  logic                         dft_cg_enable_i;
  logic                         sys_clk_i;
  logic                         efpga_clk_i;
  logic                         sys_resetn_i;
  logic                         periph_clk_i;

  logic [APB_ADDR_WIDTH-1:0]    udma_apb_paddr;
  logic [31:0]                  udma_apb_pwdata;
  logic                         udma_apb_pwrite;
  logic                         udma_apb_psel;
  logic                         udma_apb_penable;
  logic [31:0]                  udma_apb_prdata;
  logic                         udma_apb_pready;
  logic                         udma_apb_pslverr;

  logic [32*4-1:0]              events_o;
  logic                         event_valid_i;
  logic [7:0]                   event_data_i;
  logic                         event_ready_o;

  logic                         efpga_data_tx_valid_o;
  logic                         efpga_data_tx_ready_i;
  logic [31:0]                  efpga_data_tx_o;
  logic                         efpga_data_rx_valid_i;
  logic                         efpga_data_rx_ready_o;
  logic [31:0]                  efpga_data_rx_i;
  logic [31:0]                  efpga_setup_i;
  logic [31:0]                  efpga_setup_o;

  logic [`N_PERIO-1:0]          perio_in_i;
  logic [`N_PERIO-1:0]          perio_out_o;
  logic [`N_PERIO-1:0]          perio_oe_o;

  udma_subsystem #(
    .L2_DATA_WIDTH  (L2_DATA_WIDTH),
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH)
  ) dut (.*);

  initial begin
    sys_clk_i = 1'b0;
    forever #5ns sys_clk_i = ~sys_clk_i;
  end

  initial begin
    periph_clk_i = 1'b0;
    forever #7ns periph_clk_i = ~periph_clk_i;
  end

  initial begin
    efpga_clk_i = 1'b0;
    forever #11ns efpga_clk_i = ~efpga_clk_i;
  end

  initial begin
    $dumpfile("udma_subsystem_smoke.vcd");
    $dumpvars(0, udma_subsystem_smoke_tb);

    L2_ro_gnt_i          = 1'b0;
    L2_ro_rvalid_i       = 1'b0;
    L2_ro_rdata_i        = '0;
    L2_wo_gnt_i          = 1'b0;
    L2_wo_rvalid_i       = 1'b0;
    L2_wo_rdata_i        = '0;
    dft_test_mode_i      = 1'b0;
    dft_cg_enable_i      = 1'b0;
    sys_resetn_i         = 1'b0;
    udma_apb_paddr       = '0;
    udma_apb_pwdata      = '0;
    udma_apb_pwrite      = 1'b0;
    udma_apb_psel        = 1'b0;
    udma_apb_penable     = 1'b0;
    event_valid_i        = 1'b0;
    event_data_i         = '0;
    efpga_data_tx_ready_i = 1'b0;
    efpga_data_rx_valid_i = 1'b0;
    efpga_data_rx_i       = '0;
    efpga_setup_i         = '0;
    perio_in_i            = '0;

    if (`N_CAM != 0)
      $fatal(1, "Expected N_CAM=0, got %0d", `N_CAM);
    if (`N_RX_CHANNELS != 7)
      $fatal(1, "Expected N_RX_CHANNELS=7, got %0d", `N_RX_CHANNELS);
    if (`N_TX_CHANNELS != 9)
      $fatal(1, "Expected N_TX_CHANNELS=9, got %0d", `N_TX_CHANNELS);
    if (`PER_ID_EXT_PER != 8)
      $fatal(1, "Expected PER_ID_EXT_PER=8, got %0d", `PER_ID_EXT_PER);

    repeat (5) @(posedge sys_clk_i);
    sys_resetn_i = 1'b1;
    repeat (20) @(posedge sys_clk_i);

    if (L2_ro_req_o !== 1'b0)
      $fatal(1, "Unexpected read-side L2 request while the subsystem is idle");
    if (L2_wo_req_o !== 1'b0)
      $fatal(1, "Unexpected write-side L2 request while the subsystem is idle");
    if (udma_apb_pslverr !== 1'b0)
      $fatal(1, "Unexpected APB slave error while the bus is idle");

    $display(
      "PASS uDMA smoke: N_CAM=%0d RX=%0d TX=%0d PERIPHS=%0d",
      `N_CAM,
      `N_RX_CHANNELS,
      `N_TX_CHANNELS,
      `PER_ID_EXT_PER
    );
    $finish;
  end

endmodule
