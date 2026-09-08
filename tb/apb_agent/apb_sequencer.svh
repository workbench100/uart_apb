class apb_sequencer extends uvm_sequencer #(apb_item);
  `uvm_component_utils(apb_sequencer)

  virtual apb_if vif;

  function new(string name = "apb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
