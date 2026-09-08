class apb_item extends uvm_sequence_item;
  rand logic [11:0] apb_addr;
  rand logic [31:0] write_data;
  rand apb_direction_e direction;
  rand logic [3:0] strb;
  rand int unsigned idle_cycles;

  logic [31:0] read_data;
  bit          slverr;
  bit          aborted;
  int unsigned wait_cycles;

  constraint c_alignment {
    soft apb_addr[1:0] == 2'b00;
  }

  constraint c_idle_cycles {
    idle_cycles inside {[0:5]};
  }

  constraint c_read_strobe {
    direction == APB_READ -> strb == 4'b0000;
  }

  `uvm_object_utils_begin(apb_item)
    `uvm_field_int(apb_addr, UVM_ALL_ON)
    `uvm_field_int(write_data, UVM_ALL_ON)
    `uvm_field_enum(apb_direction_e, direction, UVM_ALL_ON)
    `uvm_field_int(strb, UVM_ALL_ON)
    `uvm_field_int(idle_cycles, UVM_ALL_ON)
    `uvm_field_int(read_data, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(slverr, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(aborted, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(wait_cycles, UVM_ALL_ON | UVM_NOCOMPARE)
  `uvm_object_utils_end

  function new(string name = "apb_item");
    super.new(name);
  endfunction
endclass
