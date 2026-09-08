class uart_apb_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(uart_apb_virtual_sequencer)

  apb_sequencer       apb_sqr;
  uart_sequencer      uart_sqr;
  uart_apb_reg_block  regmodel;
  virtual reset_if    reset_vif;

  function new(string name = "uart_apb_virtual_sequencer",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
