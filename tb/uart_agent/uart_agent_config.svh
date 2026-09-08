class uart_agent_config extends uvm_object;
  `uvm_object_utils(uart_agent_config)

  virtual uart_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int unsigned bit_cycles = 16;
  bit coverage_enable = 1'b1;
  bit checks_enable   = 1'b1;

  function new(string name = "uart_agent_config");
    super.new(name);
  endfunction
endclass
