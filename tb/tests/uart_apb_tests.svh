class uart_apb_smoke_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_smoke_test)
  function new(string name = "uart_apb_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class uart_apb_ral_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_ral_test)
  function new(string name = "uart_apb_ral_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_ral_vseq seq = uart_apb_ral_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_tx_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_tx_test)
  function new(string name = "uart_apb_tx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_tx_vseq seq = uart_apb_tx_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_rx_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_rx_test)
  function new(string name = "uart_apb_rx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_rx_vseq seq = uart_apb_rx_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_loopback_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_loopback_test)
  function new(string name = "uart_apb_loopback_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_loopback_vseq seq = uart_apb_loopback_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_error_response_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_error_response_test)
  function new(string name = "uart_apb_error_response_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_error_response_vseq seq =
      uart_apb_error_response_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_baud_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_baud_test)
  function new(string name = "uart_apb_baud_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_baud_vseq seq = uart_apb_baud_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_full_duplex_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_full_duplex_test)
  function new(string name = "uart_apb_full_duplex_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_full_duplex_vseq seq =
      uart_apb_full_duplex_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_irq_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_irq_test)
  function new(string name = "uart_apb_irq_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_irq_vseq seq = uart_apb_irq_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_reset_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_reset_test)
  function new(string name = "uart_apb_reset_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_reset_vseq seq = uart_apb_reset_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_random_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_random_test)
  function new(string name = "uart_apb_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_random_vseq seq = uart_apb_random_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_debug_scratch_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_debug_scratch_test)
  function new(string name = "uart_apb_debug_scratch_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_debug_scratch_vseq seq =
      uart_apb_debug_scratch_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_debug_overrun_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_debug_overrun_test)
  function new(string name = "uart_apb_debug_overrun_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_debug_overrun_vseq seq =
      uart_apb_debug_overrun_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass

class uart_apb_debug_frame_error_test extends uart_apb_base_test;
  `uvm_component_utils(uart_apb_debug_frame_error_test)
  function new(string name = "uart_apb_debug_frame_error_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual task run_main_sequence();
    uart_apb_debug_frame_error_vseq seq =
      uart_apb_debug_frame_error_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass
