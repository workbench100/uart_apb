`timescale 1ns/1ps

module tb_top #(
  parameter time        CLK_PERIOD   = 10ns,
  parameter logic [2:0] DUT_BUG_MASK = 3'b111
);
  import uvm_pkg::*;
  import uart_apb_test_pkg::*;

  logic pclk = 1'b0;
  always #(CLK_PERIOD/2) pclk = ~pclk;

  reset_if reset_bus(pclk);
  apb_if #(
    .ADDR_WIDTH(12),
    .DATA_WIDTH(32)
  ) apb_bus (
    .PCLK(pclk),
    .PRESETn(reset_bus.reset_n)
  );
  uart_if uart_bus (
    .clk(pclk),
    .reset_n(reset_bus.reset_n)
  );

  apb_uart #(
    .ADDR_WIDTH(12),
    .DATA_WIDTH(32),
    .RESET_BAUD_DIV(16),
    .BUG_MASK(DUT_BUG_MASK)
  ) dut (
    .PCLK     (pclk),
    .PRESETn  (reset_bus.reset_n),
    .PADDR    (apb_bus.PADDR),
    .PSEL     (apb_bus.PSEL),
    .PENABLE  (apb_bus.PENABLE),
    .PWRITE   (apb_bus.PWRITE),
    .PWDATA   (apb_bus.PWDATA),
    .PSTRB    (apb_bus.PSTRB),
    .PRDATA   (apb_bus.PRDATA),
    .PREADY   (apb_bus.PREADY),
    .PSLVERR  (apb_bus.PSLVERR),
    .uart_rx  (uart_bus.rx),
    .uart_tx  (uart_bus.tx),
    .irq      (uart_bus.irq)
  );

  uart_apb_protocol_checks protocol_checks (
    .pclk     (pclk),
    .presetn  (reset_bus.reset_n),
    .psel     (apb_bus.PSEL),
    .penable  (apb_bus.PENABLE),
    .pready   (apb_bus.PREADY),
    .pslverr  (apb_bus.PSLVERR),
    .uart_rx  (uart_bus.rx),
    .uart_tx  (uart_bus.tx),
    .irq      (uart_bus.irq)
  );

  initial begin
    uvm_config_db#(virtual apb_if)::set(
      null, "uvm_test_top*", "apb_vif", apb_bus);
    uvm_config_db#(virtual uart_if)::set(
      null, "uvm_test_top*", "uart_vif", uart_bus);
    uvm_config_db#(virtual reset_if)::set(
      null, "uvm_test_top*", "reset_vif", reset_bus);
    run_test();
  end

  initial begin
    reset_bus.apply_reset(8, 2);
  end

endmodule
