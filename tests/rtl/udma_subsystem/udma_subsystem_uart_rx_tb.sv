`timescale 1ns/1ps

`include "pulp_soc_defines.svh"
`include "pulp_peripheral_defines.svh"

module udma_subsystem_uart_rx_tb;

  localparam int L2_DATA_WIDTH = 32;
  localparam int APB_ADDR_WIDTH = 12;
  localparam int UART_DIV = 8;

  localparam logic [APB_ADDR_WIDTH-1:0] UDMA_CTRL_CG      = 12'h000;
  localparam logic [APB_ADDR_WIDTH-1:0] UART0_RX_SADDR    = 12'h080;
  localparam logic [APB_ADDR_WIDTH-1:0] UART0_RX_SIZE     = 12'h084;
  localparam logic [APB_ADDR_WIDTH-1:0] UART0_RX_CFG      = 12'h088;
  localparam logic [APB_ADDR_WIDTH-1:0] UART0_SETUP       = 12'h0A4;
  localparam logic [31:0]               TEST_L2_ADDR      = 32'h1C00_0200;
  localparam logic [7:0]                TEST_UART_DATA    = 8'hA5;
  localparam logic [31:0]               UART_SETUP_VALUE  = 32'h0008_0206;

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

  logic                         saw_l2_write;
  logic                         saw_rx_event;
  integer                       l2_write_count;

  udma_subsystem #(
    .L2_DATA_WIDTH  (L2_DATA_WIDTH),
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH)
  ) dut (.*);

  assign L2_ro_gnt_i = 1'b0;
  assign L2_wo_gnt_i = L2_wo_req_o;

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

  task automatic apb_write(
    input logic [APB_ADDR_WIDTH-1:0] address,
    input logic [31:0] data
  );
    integer wait_cycles;
    begin
      @(negedge sys_clk_i);
      udma_apb_paddr   = address;
      udma_apb_pwdata  = data;
      udma_apb_pwrite  = 1'b1;
      udma_apb_psel    = 1'b1;
      udma_apb_penable = 1'b0;

      @(negedge sys_clk_i);
      udma_apb_penable = 1'b1;

      wait_cycles = 0;
      do begin
        @(negedge sys_clk_i);
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 20)
          $fatal(1, "APB write timeout at address 0x%03h", address);
      end while (udma_apb_pready !== 1'b1);

      if (udma_apb_pslverr !== 1'b0)
        $fatal(1, "APB slave error during write to address 0x%03h", address);

      udma_apb_psel    = 1'b0;
      udma_apb_penable = 1'b0;
      udma_apb_pwrite  = 1'b0;
      udma_apb_paddr   = '0;
      udma_apb_pwdata  = '0;
    end
  endtask

  task automatic apb_read(
    input  logic [APB_ADDR_WIDTH-1:0] address,
    output logic [31:0] data
  );
    integer wait_cycles;
    begin
      @(negedge sys_clk_i);
      udma_apb_paddr   = address;
      udma_apb_pwrite  = 1'b0;
      udma_apb_psel    = 1'b1;
      udma_apb_penable = 1'b0;

      @(negedge sys_clk_i);
      udma_apb_penable = 1'b1;

      wait_cycles = 0;
      do begin
        @(negedge sys_clk_i);
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 20)
          $fatal(1, "APB read timeout at address 0x%03h", address);
      end while (udma_apb_pready !== 1'b1);

      if (udma_apb_pslverr !== 1'b0)
        $fatal(1, "APB slave error during read from address 0x%03h", address);

      data = udma_apb_prdata;
      udma_apb_psel    = 1'b0;
      udma_apb_penable = 1'b0;
      udma_apb_paddr   = '0;
    end
  endtask

  task automatic drive_uart_byte(input logic [7:0] data);
    begin
      // UART is idle high. Send one start bit, eight LSB-first data bits,
      // and one stop bit. Each bit lasts UART_DIV+1 peripheral clocks.
      perio_in_i[`PERIO_UART0_RX] = 1'b0;
      repeat (UART_DIV + 1) @(posedge periph_clk_i);

      for (int bit_index = 0; bit_index < 8; bit_index++) begin
        perio_in_i[`PERIO_UART0_RX] = data[bit_index];
        repeat (UART_DIV + 1) @(posedge periph_clk_i);
      end

      perio_in_i[`PERIO_UART0_RX] = 1'b1;
      repeat (UART_DIV + 2) @(posedge periph_clk_i);
    end
  endtask

  always_ff @(posedge sys_clk_i or negedge sys_resetn_i) begin
    if (!sys_resetn_i) begin
      saw_l2_write   <= 1'b0;
      saw_rx_event   <= 1'b0;
      l2_write_count <= 0;
    end else begin
      if (L2_wo_req_o && L2_wo_gnt_i) begin
        if (L2_wo_addr_o !== TEST_L2_ADDR)
          $fatal(
            1,
            "Unexpected L2 write address: expected 0x%08h, got 0x%08h",
            TEST_L2_ADDR,
            L2_wo_addr_o
          );
        if (L2_wo_wdata_o !== {24'h0, TEST_UART_DATA})
          $fatal(
            1,
            "Unexpected L2 write data: expected 0x%08h, got 0x%08h",
            {24'h0, TEST_UART_DATA},
            L2_wo_wdata_o
          );
        if (L2_wo_be_o !== 4'b0001)
          $fatal(
            1,
            "Unexpected L2 byte enable: expected 0x1, got 0x%0h",
            L2_wo_be_o
          );

        saw_l2_write   <= 1'b1;
        l2_write_count <= l2_write_count + 1;
      end

      if (events_o[0])
        saw_rx_event <= 1'b1;
    end
  end

  initial begin : test_sequence
    logic [31:0] readback;
    integer wait_cycles;

    $dumpfile("udma_subsystem_uart_rx.vcd");
    $dumpvars(0, udma_subsystem_uart_rx_tb);

    L2_ro_rvalid_i        = 1'b0;
    L2_ro_rdata_i         = '0;
    L2_wo_rvalid_i        = 1'b0;
    L2_wo_rdata_i         = '0;
    dft_test_mode_i       = 1'b0;
    dft_cg_enable_i       = 1'b0;
    sys_resetn_i          = 1'b1;
    udma_apb_paddr        = '0;
    udma_apb_pwdata       = '0;
    udma_apb_pwrite       = 1'b0;
    udma_apb_psel         = 1'b0;
    udma_apb_penable      = 1'b0;
    event_valid_i         = 1'b0;
    event_data_i          = '0;
    efpga_data_tx_ready_i = 1'b0;
    efpga_data_rx_valid_i = 1'b0;
    efpga_data_rx_i       = '0;
    efpga_setup_i         = '0;
    perio_in_i            = '1;

    #1ns;
    sys_resetn_i = 1'b0;

    if (`N_CAM != 0)
      $fatal(1, "Expected N_CAM=0, got %0d", `N_CAM);
    if (`N_RX_CHANNELS != 7)
      $fatal(1, "Expected N_RX_CHANNELS=7, got %0d", `N_RX_CHANNELS);
    if (`N_TX_CHANNELS != 9)
      $fatal(1, "Expected N_TX_CHANNELS=9, got %0d", `N_TX_CHANNELS);

    repeat (5) @(posedge sys_clk_i);
    sys_resetn_i = 1'b1;
    repeat (3) @(posedge sys_clk_i);

    apb_write(UDMA_CTRL_CG, 32'h0000_0001);
    apb_read(UDMA_CTRL_CG, readback);
    if (readback[7:0] !== 8'h01)
      $fatal(1, "Clock-gate readback mismatch: expected 0x01, got 0x%02h", readback[7:0]);

    repeat (5) @(posedge sys_clk_i);

    apb_write(UART0_SETUP, UART_SETUP_VALUE);
    apb_read(UART0_SETUP, readback);
    if (readback !== UART_SETUP_VALUE)
      $fatal(
        1,
        "UART setup readback mismatch: expected 0x%08h, got 0x%08h",
        UART_SETUP_VALUE,
        readback
      );

    apb_write(UART0_RX_SADDR, 32'h0000_0200);
    apb_write(UART0_RX_SIZE, 32'h0000_0001);
    apb_write(UART0_RX_CFG, 32'h0000_0010);

    repeat (5) @(posedge periph_clk_i);
    drive_uart_byte(TEST_UART_DATA);

    wait_cycles = 0;
    while (!(saw_l2_write && saw_rx_event)) begin
      @(posedge sys_clk_i);
      wait_cycles = wait_cycles + 1;
      if (wait_cycles > 500)
        $fatal(
          1,
          "UART RX DMA timeout: L2=%0b event=%0b writes=%0d",
          saw_l2_write,
          saw_rx_event,
          l2_write_count
        );
    end

    if (l2_write_count != 1)
      $fatal(1, "Expected exactly one L2 write, got %0d", l2_write_count);
    if (L2_ro_req_o !== 1'b0)
      $fatal(1, "Unexpected L2 read request during UART RX test");

    $display(
      "PASS uDMA UART RX: L2 addr=0x%08h, data=0x%02h, byte-enable=0x%0h, event observed",
      TEST_L2_ADDR,
      TEST_UART_DATA,
      4'b0001
    );
    $finish;
  end

endmodule
