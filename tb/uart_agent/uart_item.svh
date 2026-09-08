class uart_item extends uvm_sequence_item;
  rand logic [7:0] data;
  rand int unsigned bit_cycles;
  rand int unsigned idle_bits;
  rand bit inject_bad_stop;

  bit observed_start_error;
  bit observed_frame_error;

  constraint c_timing {
    bit_cycles inside {[2:65535]};
    idle_bits inside {[1:4]};
  }

  `uvm_object_utils_begin(uart_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(bit_cycles, UVM_ALL_ON)
    `uvm_field_int(idle_bits, UVM_ALL_ON)
    `uvm_field_int(inject_bad_stop, UVM_ALL_ON)
    `uvm_field_int(observed_start_error, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(observed_frame_error, UVM_ALL_ON | UVM_NOCOMPARE)
  `uvm_object_utils_end

  function new(string name = "uart_item");
    super.new(name);
  endfunction
endclass
