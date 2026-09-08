class uart_apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(uart_apb_reg_adapter)

  function new(string name = "uart_apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 1;
    provides_responses   = 1;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_item tr;
    tr = apb_item::type_id::create("tr");
    tr.apb_addr    = rw.addr[11:0];
    tr.direction   = (rw.kind == UVM_WRITE) ? APB_WRITE : APB_READ;
    tr.write_data  = rw.data;
    tr.strb        = (rw.kind == UVM_WRITE) ? rw.byte_en[3:0] : 4'h0;
    tr.idle_cycles = 0;
    return tr;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item,
                                ref uvm_reg_bus_op rw);
    apb_item tr;
    if (!$cast(tr, bus_item)) begin
      `uvm_fatal(get_type_name(), "bus_item is not an apb_item")
    end
    rw.kind    = (tr.direction == APB_WRITE) ? UVM_WRITE : UVM_READ;
    rw.addr    = tr.apb_addr;
    rw.data    = (tr.direction == APB_READ) ? tr.read_data : tr.write_data;
    rw.byte_en = (tr.direction == APB_WRITE) ? tr.strb : '0;
    rw.status  = (tr.slverr || tr.aborted) ? UVM_NOT_OK : UVM_IS_OK;
  endfunction
endclass
