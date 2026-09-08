class uart_data_reg extends uvm_reg;
  `uvm_object_utils(uart_data_reg)
  rand uvm_reg_field data;

  function new(string name = "uart_data_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 8, 0, "RW", 1, 8'h00, 1, 1, 0);
  endfunction
endclass

class uart_status_reg extends uvm_reg;
  `uvm_object_utils(uart_status_reg)
  uvm_reg_field tx_busy;
  uvm_reg_field tx_ready;
  uvm_reg_field rx_valid;
  uvm_reg_field rx_overrun;
  uvm_reg_field frame_error;

  function new(string name = "uart_status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    tx_busy = uvm_reg_field::type_id::create("tx_busy");
    tx_ready = uvm_reg_field::type_id::create("tx_ready");
    rx_valid = uvm_reg_field::type_id::create("rx_valid");
    rx_overrun = uvm_reg_field::type_id::create("rx_overrun");
    frame_error = uvm_reg_field::type_id::create("frame_error");
    tx_busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
    tx_ready.configure(this, 1, 1, "RO", 1, 1'b1, 1, 0, 0);
    rx_valid.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
    rx_overrun.configure(this, 1, 3, "RO", 1, 1'b0, 1, 0, 0);
    frame_error.configure(this, 1, 4, "RO", 1, 1'b0, 1, 0, 0);
  endfunction
endclass

class uart_ctrl_reg extends uvm_reg;
  `uvm_object_utils(uart_ctrl_reg)
  rand uvm_reg_field tx_en;
  rand uvm_reg_field rx_en;
  rand uvm_reg_field rx_irq_en;
  rand uvm_reg_field err_irq_en;
  rand uvm_reg_field tx_irq_en;
  rand uvm_reg_field loopback;
  uvm_reg_field clr_errors;

  function new(string name = "uart_ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    tx_en = uvm_reg_field::type_id::create("tx_en");
    rx_en = uvm_reg_field::type_id::create("rx_en");
    rx_irq_en = uvm_reg_field::type_id::create("rx_irq_en");
    err_irq_en = uvm_reg_field::type_id::create("err_irq_en");
    tx_irq_en = uvm_reg_field::type_id::create("tx_irq_en");
    loopback = uvm_reg_field::type_id::create("loopback");
    clr_errors = uvm_reg_field::type_id::create("clr_errors");
    tx_en.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
    rx_en.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
    rx_irq_en.configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 0);
    err_irq_en.configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 0);
    tx_irq_en.configure(this, 1, 4, "RW", 0, 1'b0, 1, 1, 0);
    loopback.configure(this, 1, 5, "RW", 0, 1'b0, 1, 1, 0);
    clr_errors.configure(this, 1, 8, "WO", 1, 1'b0, 1, 0, 0);
  endfunction
endclass

class uart_baud_div_reg extends uvm_reg;
  `uvm_object_utils(uart_baud_div_reg)
  rand uvm_reg_field divisor;

  function new(string name = "uart_baud_div_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    divisor = uvm_reg_field::type_id::create("divisor");
    divisor.configure(this, 16, 0, "RW", 0, 16, 1, 1, 0);
  endfunction
endclass

class uart_irq_status_reg extends uvm_reg;
  `uvm_object_utils(uart_irq_status_reg)
  uvm_reg_field rx_irq;
  uvm_reg_field err_irq;
  uvm_reg_field tx_done_irq;

  function new(string name = "uart_irq_status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    rx_irq = uvm_reg_field::type_id::create("rx_irq");
    err_irq = uvm_reg_field::type_id::create("err_irq");
    tx_done_irq = uvm_reg_field::type_id::create("tx_done_irq");
    rx_irq.configure(this, 1, 0, "W1C", 1, 1'b0, 1, 0, 0);
    err_irq.configure(this, 1, 1, "W1C", 1, 1'b0, 1, 0, 0);
    tx_done_irq.configure(this, 1, 2, "W1C", 1, 1'b0, 1, 0, 0);
  endfunction
endclass

class uart_scratch_reg extends uvm_reg;
  `uvm_object_utils(uart_scratch_reg)
  rand uvm_reg_field value;

  function new(string name = "uart_scratch_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 0, 32'h0000_0000, 1, 1, 1);
  endfunction
endclass

class uart_apb_reg_block extends uvm_reg_block;
  `uvm_object_utils(uart_apb_reg_block)

  rand uart_data_reg       data_reg;
  rand uart_status_reg     status_reg;
  rand uart_ctrl_reg       ctrl_reg;
  rand uart_baud_div_reg   baud_div_reg;
  rand uart_irq_status_reg irq_status_reg;
  rand uart_scratch_reg    scratch_reg;

  function new(string name = "uart_apb_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data_reg = uart_data_reg::type_id::create("data_reg");
    status_reg = uart_status_reg::type_id::create("status_reg");
    ctrl_reg = uart_ctrl_reg::type_id::create("ctrl_reg");
    baud_div_reg = uart_baud_div_reg::type_id::create("baud_div_reg");
    irq_status_reg = uart_irq_status_reg::type_id::create("irq_status_reg");
    scratch_reg = uart_scratch_reg::type_id::create("scratch_reg");

    data_reg.configure(this);       data_reg.build();
    status_reg.configure(this);     status_reg.build();
    ctrl_reg.configure(this);       ctrl_reg.build();
    baud_div_reg.configure(this);   baud_div_reg.build();
    irq_status_reg.configure(this); irq_status_reg.build();
    scratch_reg.configure(this);    scratch_reg.build();

    default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 1);
    default_map.add_reg(data_reg,       'h00, "RW");
    default_map.add_reg(status_reg,     'h04, "RO");
    default_map.add_reg(ctrl_reg,       'h08, "RW");
    default_map.add_reg(baud_div_reg,   'h0c, "RW");
    default_map.add_reg(irq_status_reg, 'h10, "RW");
    default_map.add_reg(scratch_reg,    'h14, "RW");

    lock_model();
  endfunction
endclass
