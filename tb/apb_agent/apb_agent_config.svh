class apb_agent_config extends uvm_object;
  `uvm_object_utils(apb_agent_config)

  virtual apb_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit coverage_enable = 1'b1;
  bit checks_enable   = 1'b1;

  function new(string name = "apb_agent_config");
    super.new(name);
  endfunction
endclass
