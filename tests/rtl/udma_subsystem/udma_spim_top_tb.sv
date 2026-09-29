`timescale 1ns/1ps

module udma_spim_top_tb;

  localparam int L2_AWIDTH_NOAL = 21;
  localparam int TRANS_SIZE = 16;

  localparam logic [4:0] REG_RX_SADDR  = 5'h00;
  localparam logic [4:0] REG_RX_SIZE   = 5'h01;
  localparam logic [4:0] REG_TX_SADDR  = 5'h04;
  localparam logic [4:0] REG_TX_SIZE   = 5'h05;
  localparam logic [4:0] REG_CMD_SADDR = 5'h08;
  localparam logic [4:0] REG_CMD_SIZE  = 5'h09;

  localparam logic [31:0] CMD_CFG     = 32'h0000_0001;
  localparam logic [31:0] CMD_SOT_CS0 = 32'h1000_0000;
  localparam logic [31:0] CMD_TX_BYTE = 32'h6007_0000;
  localparam logic [31:0] CMD_RX_BYTE = 32'h7007_0000;
  localparam logic [31:0] CMD_EOT_EVT = 32'h9000_0001;

  localparam logic [31:0] TX_WORD = 32'h0000_00A5;
  localparam logic [7:0] EXPECTED_RX_BYTE = 8'hFF;

  logic sys_clk_i;
  logic periph_clk_i;
  logic rstn_i;

  logic dft_test_mode_i;
  logic dft_cg_enable_i;

  logic spi_eot_o;
  logic [3:0] spi_event_i;

  logic [31:0] cfg_data_i;
  logic [4:0] cfg_addr_i;
  logic cfg_valid_i;
  logic cfg_rwn_i;
  logic [31:0] cfg_data_o;
  logic cfg_ready_o;

  logic [L2_AWIDTH_NOAL-1:0] cfg_cmd_startaddr_o;
  logic [TRANS_SIZE-1:0] cfg_cmd_size_o;
  logic cfg_cmd_continuous_o;
  logic cfg_cmd_en_o;
  logic cfg_cmd_clr_o;
  logic cfg_cmd_en_i;
  logic cfg_cmd_pending_i;
  logic [L2_AWIDTH_NOAL-1:0] cfg_cmd_curr_addr_i;
  logic [TRANS_SIZE-1:0] cfg_cmd_bytes_left_i;

  logic [L2_AWIDTH_NOAL-1:0] cfg_rx_startaddr_o;
  logic [TRANS_SIZE-1:0] cfg_rx_size_o;
  logic cfg_rx_continuous_o;
  logic cfg_rx_en_o;
  logic cfg_rx_clr_o;
  logic cfg_rx_en_i;
  logic cfg_rx_pending_i;
  logic [L2_AWIDTH_NOAL-1:0] cfg_rx_curr_addr_i;
  logic [TRANS_SIZE-1:0] cfg_rx_bytes_left_i;

  logic [L2_AWIDTH_NOAL-1:0] cfg_tx_startaddr_o;
  logic [TRANS_SIZE-1:0] cfg_tx_size_o;
  logic cfg_tx_continuous_o;
  logic cfg_tx_en_o;
  logic cfg_tx_clr_o;
  logic cfg_tx_en_i;
  logic cfg_tx_pending_i;
  logic [L2_AWIDTH_NOAL-1:0] cfg_tx_curr_addr_i;
  logic [TRANS_SIZE-1:0] cfg_tx_bytes_left_i;

  logic cmd_req_o;
  logic cmd_gnt_i;
  logic [1:0] cmd_datasize_o;
  logic [31:0] cmd_i;
  logic cmd_valid_i;
  logic cmd_ready_o;

  logic data_tx_req_o;
  logic data_tx_gnt_i;
  logic [1:0] data_tx_datasize_o;
  logic [31:0] data_tx_i;
  logic data_tx_valid_i;
  logic data_tx_ready_o;

  logic [1:0] data_rx_datasize_o;
  logic [31:0] data_rx_o;
  logic data_rx_valid_o;
  logic data_rx_ready_i;

  logic spi_clk_o;
  logic spi_csn0_o;
  logic spi_csn1_o;
  logic spi_csn2_o;
  logic spi_csn3_o;
  logic spi_oe0_o;
  logic spi_oe1_o;
  logic spi_oe2_o;
  logic spi_oe3_o;
  logic spi_sdo0_o;
  logic spi_sdo1_o;
  logic spi_sdo2_o;
  logic spi_sdo3_o;
  logic spi_sdi0_i;
  logic spi_sdi1_i;
  logic spi_sdi2_i;
  logic spi_sdi3_i;

  logic saw_cs0_active;
  logic saw_spi_clock;
  logic saw_mosi_zero;
  logic saw_mosi_one;
  logic saw_rx_data;
  logic [31:0] captured_rx_data;
  logic saw_eot;
  integer spi_rising_edges;
  integer cmd_handshakes;
  integer tx_handshakes;

  udma_spim_top #(
    .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
    .TRANS_SIZE(TRANS_SIZE)
  ) dut (.*);

  initial begin
    sys_clk_i = 1'b0;
    forever #5ns sys_clk_i = ~sys_clk_i;
  end

  initial begin
    periph_clk_i = 1'b0;
    forever #7ns periph_clk_i = ~periph_clk_i;
  end

  task automatic cfg_write(
    input logic [4:0] address,
    input logic [31:0] data
  );
    begin
      @(negedge sys_clk_i);
      cfg_addr_i  = address;
      cfg_data_i  = data;
      cfg_rwn_i   = 1'b0;
      cfg_valid_i = 1'b1;

      @(negedge sys_clk_i);
      if (cfg_ready_o !== 1'b1)
        $fatal(1, "SPI configuration write was not acknowledged at address 0x%02h", address);
      cfg_valid_i = 1'b0;
      cfg_addr_i  = '0;
      cfg_data_i  = '0;
    end
  endtask

  task automatic provide_command(input logic [31:0] command_word);
    integer wait_cycles;
    begin
      wait_cycles = 0;
      while (cmd_req_o !== 1'b1) begin
        @(posedge sys_clk_i);
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 100)
          $fatal(1, "Timed out waiting for SPI command DMA request");
      end

      @(negedge sys_clk_i);
      cmd_i       = command_word;
      cmd_gnt_i   = 1'b1;
      cmd_valid_i = 1'b1;

      @(negedge sys_clk_i);
      if (cmd_ready_o !== 1'b1)
        $fatal(1, "SPI command FIFO did not accept command 0x%08h", command_word);
      cmd_gnt_i   = 1'b0;
      cmd_valid_i = 1'b0;
      cmd_i       = '0;
    end
  endtask

  task automatic provide_tx_word(input logic [31:0] data_word);
    integer wait_cycles;
    begin
      wait_cycles = 0;
      while (data_tx_req_o !== 1'b1) begin
        @(posedge sys_clk_i);
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 100)
          $fatal(1, "Timed out waiting for SPI TX DMA request");
      end

      @(negedge sys_clk_i);
      data_tx_i       = data_word;
      data_tx_gnt_i   = 1'b1;
      data_tx_valid_i = 1'b1;

      @(negedge sys_clk_i);
      if (data_tx_ready_o !== 1'b1)
        $fatal(1, "SPI TX FIFO did not accept data 0x%08h", data_word);
      data_tx_gnt_i   = 1'b0;
      data_tx_valid_i = 1'b0;
      data_tx_i       = '0;
    end
  endtask

  always_ff @(posedge sys_clk_i or negedge rstn_i) begin
    if (!rstn_i) begin
      saw_rx_data      <= 1'b0;
      captured_rx_data <= '0;
      saw_eot          <= 1'b0;
      cmd_handshakes   <= 0;
      tx_handshakes    <= 0;
    end else begin
      if (cmd_valid_i && cmd_ready_o)
        cmd_handshakes <= cmd_handshakes + 1;
      if (data_tx_valid_i && data_tx_ready_o)
        tx_handshakes <= tx_handshakes + 1;
      if (data_rx_valid_o && data_rx_ready_i) begin
        saw_rx_data      <= 1'b1;
        captured_rx_data <= data_rx_o;
      end
      if (spi_eot_o)
        saw_eot <= 1'b1;
    end
  end

  always @(negedge spi_csn0_o) begin
    if (rstn_i)
      saw_cs0_active = 1'b1;
  end

  always @(posedge spi_clk_o) begin
    if (rstn_i && !spi_csn0_o) begin
      saw_spi_clock = 1'b1;
      spi_rising_edges = spi_rising_edges + 1;
      if (spi_oe0_o) begin
        if (spi_sdo0_o)
          saw_mosi_one = 1'b1;
        else
          saw_mosi_zero = 1'b1;
      end
    end
  end

  initial begin : test_sequence
    integer wait_cycles;

    $dumpfile("udma_spim_top.vcd");
    $dumpvars(0, udma_spim_top_tb);

    rstn_i = 1'b1;
    dft_test_mode_i = 1'b0;
    dft_cg_enable_i = 1'b0;
    spi_event_i = '0;
    cfg_data_i = '0;
    cfg_addr_i = '0;
    cfg_valid_i = 1'b0;
    cfg_rwn_i = 1'b0;

    cfg_cmd_en_i = 1'b0;
    cfg_cmd_pending_i = 1'b0;
    cfg_cmd_curr_addr_i = '0;
    cfg_cmd_bytes_left_i = '0;
    cfg_rx_en_i = 1'b0;
    cfg_rx_pending_i = 1'b0;
    cfg_rx_curr_addr_i = '0;
    cfg_rx_bytes_left_i = '0;
    cfg_tx_en_i = 1'b0;
    cfg_tx_pending_i = 1'b0;
    cfg_tx_curr_addr_i = '0;
    cfg_tx_bytes_left_i = '0;

    cmd_gnt_i = 1'b0;
    cmd_i = '0;
    cmd_valid_i = 1'b0;
    data_tx_gnt_i = 1'b0;
    data_tx_i = '0;
    data_tx_valid_i = 1'b0;
    data_rx_ready_i = 1'b1;

    spi_sdi0_i = 1'b0;
    spi_sdi1_i = 1'b1;
    spi_sdi2_i = 1'b0;
    spi_sdi3_i = 1'b0;

    saw_cs0_active = 1'b0;
    saw_spi_clock = 1'b0;
    saw_mosi_zero = 1'b0;
    saw_mosi_one = 1'b0;
    spi_rising_edges = 0;

    #1ns;
    rstn_i = 1'b0;
    repeat (5) @(posedge sys_clk_i);
    rstn_i = 1'b1;
    repeat (4) @(posedge sys_clk_i);

    cfg_write(REG_CMD_SADDR, 32'h0000_0100);
    cfg_write(REG_CMD_SIZE, 32'h0000_0014);
    cfg_write(REG_TX_SADDR, 32'h0000_0200);
    cfg_write(REG_TX_SIZE, 32'h0000_0001);
    cfg_write(REG_RX_SADDR, 32'h0000_0300);
    cfg_write(REG_RX_SIZE, 32'h0000_0001);

    if (cfg_cmd_startaddr_o !== 21'h00100 || cfg_cmd_size_o !== 16'h0014)
      $fatal(1, "SPI command channel configuration did not latch correctly");
    if (cfg_tx_startaddr_o !== 21'h00200 || cfg_tx_size_o !== 16'h0001)
      $fatal(1, "SPI TX channel configuration did not latch correctly");
    if (cfg_rx_startaddr_o !== 21'h00300 || cfg_rx_size_o !== 16'h0001)
      $fatal(1, "SPI RX channel configuration did not latch correctly");

    provide_tx_word(TX_WORD);
    provide_command(CMD_CFG);
    provide_command(CMD_SOT_CS0);
    provide_command(CMD_TX_BYTE);
    provide_command(CMD_RX_BYTE);
    provide_command(CMD_EOT_EVT);

    wait_cycles = 0;
    while (!(saw_cs0_active && saw_spi_clock && saw_mosi_zero &&
             saw_mosi_one && saw_rx_data && saw_eot)) begin
      @(posedge sys_clk_i);
      wait_cycles = wait_cycles + 1;
      if (wait_cycles > 2000)
        $fatal(
          1,
          "SPI transaction timeout: cs=%0b clk=%0b mosi0=%0b mosi1=%0b rx=%0b eot=%0b edges=%0d",
          saw_cs0_active,
          saw_spi_clock,
          saw_mosi_zero,
          saw_mosi_one,
          saw_rx_data,
          saw_eot,
          spi_rising_edges
        );
    end

    if (captured_rx_data[7:0] !== EXPECTED_RX_BYTE)
      $fatal(
        1,
        "SPI RX mismatch: expected 0x%02h from high MISO, got 0x%02h",
        EXPECTED_RX_BYTE,
        captured_rx_data[7:0]
      );
    if (cmd_handshakes != 5)
      $fatal(1, "Expected five SPI command handshakes, got %0d", cmd_handshakes);
    if (tx_handshakes != 1)
      $fatal(1, "Expected one SPI TX data handshake, got %0d", tx_handshakes);
    if (spi_rising_edges < 16)
      $fatal(1, "Expected at least 16 SPI rising edges, got %0d", spi_rising_edges);
    if (spi_csn1_o !== 1'b1 || spi_csn2_o !== 1'b1 || spi_csn3_o !== 1'b1)
      $fatal(1, "An unselected SPI chip-select became active");

    $display(
      "PASS uDMA SPI top: config, CMD=%0d, TX=0x%02h, RX=0x%02h, edges=%0d, EOT observed",
      cmd_handshakes,
      TX_WORD[7:0],
      captured_rx_data[7:0],
      spi_rising_edges
    );
    $finish;
  end

endmodule
