class uart_apb_env_config extends uvm_object;
  `uvm_object_utils(uart_apb_env_config)

  apb_agent_config  apb_cfg;
  uart_agent_config uart_cfg;
  virtual reset_if  reset_vif;

  bit scoreboard_enable = 1'b1;
  bit ral_enable        = 1'b1;

  function new(string name = "uart_apb_env_config");
    super.new(name);
  endfunction
endclass
