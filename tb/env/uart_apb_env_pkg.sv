package uart_apb_env_pkg;
  import uvm_pkg::*;
  import uart_apb_regs_pkg::*;
  import apb_agent_pkg::*;
  import uart_agent_pkg::*;
  `include "uvm_macros.svh"

  `include "uart_apb_env_config.svh"
  `include "uart_apb_reg_model.svh"
  `include "uart_apb_reg_adapter.svh"
  `include "uart_apb_virtual_sequencer.svh"
  `include "uart_apb_scoreboard.svh"
  `include "uart_apb_env.svh"
  `include "uart_apb_virtual_sequences.svh"
endpackage
