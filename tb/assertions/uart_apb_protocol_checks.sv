`timescale 1ns/1ps

module uart_apb_protocol_checks (
  input logic pclk,
  input logic presetn,
  input logic psel,
  input logic penable,
  input logic pready,
  input logic pslverr,
  input logic uart_rx,
  input logic uart_tx,
  input logic irq
);

`ifndef SYNTHESIS
  property p_zero_wait_dut;
    @(posedge pclk) disable iff (!presetn)
      (psel && penable) |-> pready;
  endproperty

  property p_error_only_in_access;
    @(posedge pclk) disable iff (!presetn)
      pslverr |-> (psel && penable && pready);
  endproperty

  property p_tx_high_during_reset;
    @(posedge pclk)
      !presetn |=> (uart_tx === 1'b1);
  endproperty

  property p_irq_known;
    @(posedge pclk) disable iff (!presetn)
      !$isunknown(irq);
  endproperty

  a_zero_wait_dut:
    assert property (p_zero_wait_dut)
      else $error("DUT unexpectedly inserted an APB wait state");

  a_error_only_in_access:
    assert property (p_error_only_in_access)
      else $error("PSLVERR asserted outside a completed APB access");

  a_tx_high_during_reset:
    assert property (p_tx_high_during_reset)
      else $error("UART TX is not idle-high during reset");

  a_irq_known:
    assert property (p_irq_known)
      else $error("IRQ contains X/Z after reset");

  c_uart_tx_start:
    cover property (@(posedge pclk) disable iff (!presetn) $fell(uart_tx));

  c_uart_rx_start:
    cover property (@(posedge pclk) disable iff (!presetn) $fell(uart_rx));

  c_irq_asserted:
    cover property (@(posedge pclk) disable iff (!presetn) $rose(irq));
`endif

endmodule
