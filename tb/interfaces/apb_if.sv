`timescale 1ns/1ps

interface apb_if #(
  parameter int unsigned ADDR_WIDTH = 12,
  parameter int unsigned DATA_WIDTH = 32
) (
  input logic PCLK,
  input logic PRESETn
);

  logic [ADDR_WIDTH-1:0]     PADDR;
  logic                      PSEL;
  logic                      PENABLE;
  logic                      PWRITE;
  logic [DATA_WIDTH-1:0]     PWDATA;
  logic [(DATA_WIDTH/8)-1:0] PSTRB;
  logic [DATA_WIDTH-1:0]     PRDATA;
  logic                      PREADY;
  logic                      PSLVERR;

  clocking drv_cb @(posedge PCLK);
    default input #1step output #0;
    output PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
    input  PRDATA, PREADY, PSLVERR, PRESETn;
  endclocking

  clocking mon_cb @(posedge PCLK);
    default input #1step;
    input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
    input PRDATA, PREADY, PSLVERR, PRESETn;
  endclocking

`ifndef SYNTHESIS
  property p_enable_requires_select;
    @(posedge PCLK) disable iff (!PRESETn)
      PENABLE |-> PSEL;
  endproperty

  property p_setup_to_access;
    @(posedge PCLK) disable iff (!PRESETn)
      (PSEL && !PENABLE) |=> (PSEL && PENABLE);
  endproperty

  property p_control_stable_while_waiting;
    @(posedge PCLK) disable iff (!PRESETn)
      (PSEL && PENABLE && !PREADY) |=>
        (PSEL && PENABLE && $stable({PADDR, PWRITE, PWDATA, PSTRB}));
  endproperty

  property p_known_during_access;
    @(posedge PCLK) disable iff (!PRESETn)
      (PSEL && PENABLE) |->
        !$isunknown({PADDR, PWRITE, PWDATA, PSTRB, PREADY, PSLVERR});
  endproperty

  a_enable_requires_select:
    assert property (p_enable_requires_select)
      else $error("APB protocol: PENABLE asserted without PSEL");

  a_setup_to_access:
    assert property (p_setup_to_access)
      else $error("APB protocol: setup phase not followed by access phase");

  a_control_stable_while_waiting:
    assert property (p_control_stable_while_waiting)
      else $error("APB protocol: control changed while PREADY was low");

  a_known_during_access:
    assert property (p_known_during_access)
      else $error("APB protocol: unknown value during access phase");

  c_error_response:
    cover property (@(posedge PCLK) disable iff (!PRESETn)
      PSEL && PENABLE && PREADY && PSLVERR);
`endif

endinterface
