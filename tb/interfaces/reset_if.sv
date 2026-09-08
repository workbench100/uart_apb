`timescale 1ns/1ps

interface reset_if (input logic clk);
  logic reset_n;

  initial reset_n = 1'b0;

  task automatic apply_reset(int unsigned low_cycles = 5,
                             int unsigned settle_cycles = 2);
    reset_n <= 1'b0;
    repeat (low_cycles) @(posedge clk);
    reset_n <= 1'b1;
    repeat (settle_cycles) @(posedge clk);
  endtask
endinterface
