`timescale 1ns/1ps

interface uart_if (
  input logic clk,
  input logic reset_n
);
  logic rx;
  logic tx;
  logic irq;

  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output rx;
    input tx, irq, reset_n;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rx, tx, irq, reset_n;
  endclocking

`ifndef SYNTHESIS
  property p_tx_idle_in_reset;
    @(posedge clk) !reset_n |=> (tx === 1'b1);
  endproperty

  property p_outputs_known_after_reset;
    @(posedge clk) disable iff (!reset_n)
      !$isunknown({tx, irq});
  endproperty

  a_tx_idle_in_reset:
    assert property (p_tx_idle_in_reset)
      else $error("UART TX must be high while reset is active");

  a_outputs_known_after_reset:
    assert property (p_outputs_known_after_reset)
      else $error("UART output or IRQ contains X/Z after reset");
`endif

endinterface
