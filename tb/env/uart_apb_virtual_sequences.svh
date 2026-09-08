class uart_apb_base_vseq extends uvm_sequence;
  `uvm_object_utils(uart_apb_base_vseq)
  `uvm_declare_p_sequencer(uart_apb_virtual_sequencer)

  function new(string name = "uart_apb_base_vseq");
    super.new(name);
  endfunction

  task apb_write(input logic [11:0] addr,
                 input logic [31:0] data,
                 input logic [3:0] strb = 4'hf,
                 input bit expect_slverr = 1'b0,
                 input int unsigned idle_cycles = 0);
    apb_single_seq seq;
    seq = apb_single_seq::type_id::create("apb_write_seq");
    seq.direction   = APB_WRITE;
    seq.apb_addr    = addr;
    seq.write_data  = data;
    seq.strb        = strb;
    seq.idle_cycles = idle_cycles;
    seq.start(p_sequencer.apb_sqr);
    if (seq.aborted) begin
      `uvm_error(get_type_name(),
        $sformatf("APB write to 0x%03h was aborted by reset", addr))
    end else if (seq.slverr != expect_slverr) begin
      `uvm_error(get_type_name(),
        $sformatf("APB write 0x%03h PSLVERR expected=%0b actual=%0b",
                  addr, expect_slverr, seq.slverr))
    end
  endtask

  task apb_read(input logic [11:0] addr,
                output logic [31:0] data,
                input bit expect_slverr = 1'b0,
                input int unsigned idle_cycles = 0);
    apb_single_seq seq;
    seq = apb_single_seq::type_id::create("apb_read_seq");
    seq.direction   = APB_READ;
    seq.apb_addr    = addr;
    seq.idle_cycles = idle_cycles;
    seq.start(p_sequencer.apb_sqr);
    data = seq.read_data;
    if (seq.aborted) begin
      `uvm_error(get_type_name(),
        $sformatf("APB read from 0x%03h was aborted by reset", addr))
    end else if (seq.slverr != expect_slverr) begin
      `uvm_error(get_type_name(),
        $sformatf("APB read 0x%03h PSLVERR expected=%0b actual=%0b",
                  addr, expect_slverr, seq.slverr))
    end
  endtask

  task uart_send(input logic [7:0] data,
                 input bit bad_stop = 1'b0,
                 input int unsigned idle_bits = 1);
    uart_send_seq seq;
    seq = uart_send_seq::type_id::create("uart_send_seq");
    seq.data            = data;
    seq.bit_cycles      = p_sequencer.uart_sqr.cfg.bit_cycles;
    seq.idle_bits       = idle_bits;
    seq.inject_bad_stop = bad_stop;
    seq.start(p_sequencer.uart_sqr);
  endtask

  task configure_uart(input logic [15:0] divisor,
                      input logic [5:0] ctrl);
    apb_write(UART_BAUD_DIV_ADDR, {16'h0000, divisor});
    // Avoid a same-timestep race between the APB monitor and a following
    // UART child sequence. The scoreboard updates this shared object too.
    p_sequencer.uart_sqr.cfg.bit_cycles = divisor;
    apb_write(UART_CTRL_ADDR, {26'h0, ctrl});
  endtask

  task wait_tx_idle(input int unsigned max_polls = 256);
    logic [31:0] status;
    for (int unsigned poll = 0; poll < max_polls; poll++) begin
      apb_read(UART_STATUS_ADDR, status);
      if (!status[STATUS_TX_BUSY_BIT]) begin
        return;
      end
    end
    `uvm_fatal(get_type_name(), "Timeout waiting for UART TX idle")
  endtask

  task wait_rx_valid(input int unsigned max_polls = 256);
    logic [31:0] status;
    for (int unsigned poll = 0; poll < max_polls; poll++) begin
      apb_read(UART_STATUS_ADDR, status);
      if (status[STATUS_RX_VALID_BIT]) begin
        return;
      end
    end
    `uvm_fatal(get_type_name(), "Timeout waiting for UART RX valid")
  endtask

  task wait_irq(input bit expected_value,
                input int unsigned max_cycles = 64);
    for (int unsigned cycle = 0; cycle < max_cycles; cycle++) begin
      @(p_sequencer.uart_sqr.vif.mon_cb);
      if (p_sequencer.uart_sqr.vif.mon_cb.irq === expected_value) begin
        return;
      end
    end
    `uvm_error(get_type_name(),
      $sformatf("Timeout waiting for irq=%0b", expected_value))
  endtask
endclass

class uart_apb_smoke_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_smoke_vseq)

  function new(string name = "uart_apb_smoke_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;
    configure_uart(16, 6'b00_0011);

    apb_write(UART_DATA_ADDR, 32'h0000_00a5, 4'b0001);
    wait_tx_idle();

    uart_send(8'h3c);
    wait_rx_valid();
    if (p_sequencer.uart_sqr.vif.irq !== 1'b0) begin
      `uvm_error(get_type_name(),
        "IRQ asserted even though all interrupt enables are clear")
    end
    apb_read(UART_DATA_ADDR, data);
    if (data[7:0] !== 8'h3c) begin
      `uvm_error(get_type_name(),
        $sformatf("Smoke RX expected 0x3c, got 0x%02h", data[7:0]))
    end
  endtask
endclass

class uart_apb_tx_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_tx_vseq)

  function new(string name = "uart_apb_tx_vseq");
    super.new(name);
  endfunction

  task body();
    logic [7:0] values[$] = '{8'h00, 8'hff, 8'h55, 8'haa,
                              8'h01, 8'h02, 8'h04, 8'h08,
                              8'h10, 8'h20, 8'h40, 8'h80,
                              8'hfe, 8'hfd, 8'hfb, 8'hf7,
                              8'hef, 8'hdf, 8'hbf, 8'h7f};
    configure_uart(16, 6'b00_0001);
    foreach (values[index]) begin
      wait_tx_idle();
      apb_write(UART_DATA_ADDR, {24'h0, values[index]}, 4'b0001);
    end
    wait_tx_idle();
  endtask
endclass

class uart_apb_rx_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_rx_vseq)

  function new(string name = "uart_apb_rx_vseq");
    super.new(name);
  endfunction

  task body();
    logic [7:0] values[$] = '{8'h00, 8'hff, 8'h55, 8'haa,
                              8'h01, 8'h02, 8'h04, 8'h08,
                              8'h10, 8'h20, 8'h40, 8'h80,
                              8'hfe, 8'hfd, 8'hfb, 8'hf7,
                              8'hef, 8'hdf, 8'hbf, 8'h7f};
    logic [31:0] data;
    configure_uart(16, 6'b00_0010);
    foreach (values[index]) begin
      uart_send(values[index]);
      wait_rx_valid();
      apb_read(UART_DATA_ADDR, data);
      if (data[7:0] !== values[index]) begin
        `uvm_error(get_type_name(),
          $sformatf("RX[%0d] expected 0x%02h, got 0x%02h",
                    index, values[index], data[7:0]))
      end
    end
    apb_read(UART_DATA_ADDR, data);
    if (data !== 32'h0000_0000) begin
      `uvm_error(get_type_name(), "Empty DATA read did not return zero")
    end
  endtask
endclass

class uart_apb_loopback_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_loopback_vseq)

  function new(string name = "uart_apb_loopback_vseq");
    super.new(name);
  endfunction

  task body();
    logic [7:0] values[$] = '{8'h12, 8'h34, 8'ha5, 8'h5a};
    logic [31:0] data;
    configure_uart(16, 6'b10_0011);
    foreach (values[index]) begin
      wait_tx_idle();
      apb_write(UART_DATA_ADDR, {24'h0, values[index]}, 4'b0001);
      wait_rx_valid();
      apb_read(UART_DATA_ADDR, data);
      if (data[7:0] !== values[index]) begin
        `uvm_error(get_type_name(),
          $sformatf("Loopback expected 0x%02h, got 0x%02h",
                    values[index], data[7:0]))
      end
    end
    wait_tx_idle();
  endtask
endclass

class uart_apb_error_response_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_error_response_vseq)

  function new(string name = "uart_apb_error_response_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;

    apb_write(UART_DATA_ADDR, 32'h55, 4'b0001, 1'b1);
    apb_write(UART_STATUS_ADDR, 32'hffff_ffff, 4'hf, 1'b1);
    apb_read(12'h018, data, 1'b1);
    apb_read(12'h005, data, 1'b1);
    apb_write(UART_BAUD_DIV_ADDR, 32'h1, 4'b0011, 1'b1);

    configure_uart(16, 6'b00_0001);
    apb_write(UART_DATA_ADDR, 32'h11, 4'b0001);
    apb_write(UART_DATA_ADDR, 32'h22, 4'b0001, 1'b1);
    wait_tx_idle();
  endtask
endclass

class uart_apb_baud_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_baud_vseq)

  function new(string name = "uart_apb_baud_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned divisors[6] = '{2, 4, 7, 16, 31, 64};
    logic [31:0] data;

    foreach (divisors[index]) begin
      configure_uart(divisors[index][15:0], 6'b00_0011);
      apb_write(UART_DATA_ADDR, 32'h40 + index, 4'b0001);
      wait_tx_idle(512);
      uart_send(8'h80 + index);
      wait_rx_valid();
      apb_read(UART_DATA_ADDR, data);
      if (data[7:0] !== (8'h80 + index)) begin
        `uvm_error(get_type_name(),
          $sformatf("Baud case %0d RX mismatch: 0x%02h",
                    divisors[index], data[7:0]))
      end
    end
  endtask
endclass

class uart_apb_full_duplex_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_full_duplex_vseq)

  function new(string name = "uart_apb_full_duplex_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;
    configure_uart(16, 6'b00_0011);
    fork
      begin
        apb_write(UART_DATA_ADDR, 32'h0000_0096, 4'b0001);
        wait_tx_idle();
      end
      begin
        uart_send(8'h69, 1'b0, 2);
        wait_rx_valid();
        apb_read(UART_DATA_ADDR, data);
        if (data[7:0] !== 8'h69) begin
          `uvm_error(get_type_name(), "Full-duplex RX comparison failed")
        end
      end
    join
  endtask
endclass

class uart_apb_irq_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_irq_vseq)

  function new(string name = "uart_apb_irq_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;
    configure_uart(16, 6'b01_1111);

    uart_send(8'hc3);
    wait_rx_valid();
    wait_irq(1'b1);
    apb_read(UART_IRQ_STATUS_ADDR, data);
    if (!data[IRQ_RX_BIT]) begin
      `uvm_error(get_type_name(), "RX interrupt status did not set")
    end
    apb_read(UART_DATA_ADDR, data);
    apb_write(UART_IRQ_STATUS_ADDR, 32'h1, 4'b0001);
    wait_irq(1'b0);

    uart_send(8'h5a, 1'b1);
    wait_rx_valid();
    wait_irq(1'b1);
    apb_read(UART_IRQ_STATUS_ADDR, data);
    if (data[IRQ_ERR_BIT:IRQ_RX_BIT] !== 2'b11) begin
      `uvm_error(get_type_name(),
        $sformatf("RX/error interrupt bits expected 2'b11, got %02b",
                  data[IRQ_ERR_BIT:IRQ_RX_BIT]))
    end
    apb_read(UART_DATA_ADDR, data);
    apb_write(UART_IRQ_STATUS_ADDR, 32'h3, 4'b0001);
    apb_write(UART_CTRL_ADDR, 32'h0000_011f, 4'b0011);
    wait_irq(1'b0);

    apb_write(UART_DATA_ADDR, 32'ha6, 4'b0001);
    wait_tx_idle();
    wait_irq(1'b1);
    apb_read(UART_IRQ_STATUS_ADDR, data);
    if (!data[IRQ_TX_DONE_BIT]) begin
      `uvm_error(get_type_name(), "TX-done interrupt status did not set")
    end
    apb_write(UART_IRQ_STATUS_ADDR, 32'h4, 4'b0001);
    wait_irq(1'b0);
  endtask
endclass

class uart_apb_ral_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_ral_vseq)

  function new(string name = "uart_apb_ral_vseq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e   status;
    uvm_reg_data_t data;

    p_sequencer.regmodel.status_reg.read(
      status, data, UVM_FRONTDOOR,
      p_sequencer.regmodel.default_map, this);
    if (status != UVM_IS_OK || data[4:0] !== 5'b0_0010) begin
      `uvm_error(get_type_name(),
        $sformatf("RAL STATUS reset read failed: status=%s data=0x%08h",
                  status.name(), data))
    end

    p_sequencer.regmodel.scratch_reg.write(
      status, 32'hcafe_babe, UVM_FRONTDOOR,
      p_sequencer.regmodel.default_map, this);
    p_sequencer.regmodel.scratch_reg.read(
      status, data, UVM_FRONTDOOR,
      p_sequencer.regmodel.default_map, this);
    if (status != UVM_IS_OK || data !== 32'hcafe_babe) begin
      `uvm_error(get_type_name(), "RAL SCRATCH write/read failed")
    end

    p_sequencer.regmodel.baud_div_reg.write(
      status, 32'd20, UVM_FRONTDOOR,
      p_sequencer.regmodel.default_map, this);
    p_sequencer.regmodel.baud_div_reg.read(
      status, data, UVM_FRONTDOOR,
      p_sequencer.regmodel.default_map, this);
    if (status != UVM_IS_OK || data[15:0] !== 16'd20) begin
      `uvm_error(get_type_name(), "RAL BAUD_DIV write/read failed")
    end

    apb_write(UART_BAUD_DIV_ADDR, 32'h0000_1234, 4'b0011);
    apb_write(UART_BAUD_DIV_ADDR, 32'h0000_0056, 4'b0001);
    apb_read(UART_BAUD_DIV_ADDR, data);
    if (data[15:0] !== 16'h1256) begin
      `uvm_error(get_type_name(), "BAUD_DIV partial-byte write failed")
    end

    p_sequencer.regmodel.ctrl_reg.write(
      status, 32'h0000_0003, UVM_FRONTDOOR,
      p_sequencer.regmodel.default_map, this);
    p_sequencer.regmodel.ctrl_reg.read(
      status, data, UVM_FRONTDOOR,
      p_sequencer.regmodel.default_map, this);
    if (status != UVM_IS_OK || data[5:0] !== 6'h03) begin
      `uvm_error(get_type_name(), "RAL CTRL write/read failed")
    end
  endtask
endclass

class uart_apb_reset_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_reset_vseq)

  function new(string name = "uart_apb_reset_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;

    configure_uart(16, 6'b00_0011);
    fork
      begin
        apb_write(UART_DATA_ADDR, 32'hde, 4'b0001);
      end
      begin
        uart_send(8'had, 1'b0, 1);
      end
      begin
        repeat (24) @(p_sequencer.apb_sqr.vif.drv_cb);
        p_sequencer.reset_vif.apply_reset(5, 2);
      end
    join

    apb_read(UART_CTRL_ADDR, data);
    if (data[5:0] !== 6'h00) begin
      `uvm_error(get_type_name(), "CTRL did not return to reset value")
    end
    apb_read(UART_BAUD_DIV_ADDR, data);
    if (data[15:0] !== 16'd16) begin
      `uvm_error(get_type_name(), "BAUD_DIV did not return to reset value")
    end

    configure_uart(16, 6'b00_0011);
    uart_send(8'h42);
    wait_rx_valid();
    apb_read(UART_DATA_ADDR, data);
    if (data[7:0] !== 8'h42) begin
      `uvm_error(get_type_name(), "RX did not recover after reset")
    end
  endtask
endclass

class uart_apb_random_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_random_vseq)

  int unsigned operation_count = 30;

  function new(string name = "uart_apb_random_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;
    logic [7:0] random_byte;
    int unsigned operation;

    configure_uart(16, 6'b00_0011);
    repeat (operation_count) begin
      operation   = $urandom_range(0, 3);
      random_byte = $urandom();
      case (operation)
        0: begin
          wait_tx_idle();
          apb_write(UART_DATA_ADDR, {24'h0, random_byte}, 4'b0001,
                    1'b0, $urandom_range(0, 3));
        end
        1: begin
          uart_send(random_byte, 1'b0, $urandom_range(1, 3));
          wait_rx_valid();
          apb_read(UART_DATA_ADDR, data);
        end
        2: begin
          apb_write(UART_SCRATCH_ADDR, $urandom(), 4'hf);
          apb_read(UART_SCRATCH_ADDR, data);
        end
        default: begin
          apb_read(UART_STATUS_ADDR, data,
                   1'b0, $urandom_range(0, 3));
        end
      endcase
    end
    wait_tx_idle();
  endtask
endclass

class uart_apb_debug_scratch_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_debug_scratch_vseq)

  function new(string name = "uart_apb_debug_scratch_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] baseline;
    logic [31:0] update_value;
    logic [31:0] expected;
    logic [31:0] data;
    baseline     = 32'h1122_3344;
    update_value = 32'hddee_aabb;

    for (int unsigned strobe = 0; strobe < 16; strobe++) begin
      expected = baseline;
      for (int unsigned byte_index = 0; byte_index < 4; byte_index++) begin
        if (strobe[byte_index]) begin
          expected[byte_index*8 +: 8] =
            update_value[byte_index*8 +: 8];
        end
      end

      apb_write(UART_SCRATCH_ADDR, baseline, 4'b1111);
      apb_write(UART_SCRATCH_ADDR, update_value, strobe[3:0]);
      apb_read(UART_SCRATCH_ADDR, data);
      if (data !== expected) begin
        `uvm_error(get_type_name(),
          $sformatf("PSTRB=%04b expected 0x%08h, got 0x%08h",
                    strobe[3:0], expected, data))
      end
    end
  endtask
endclass

class uart_apb_debug_overrun_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_debug_overrun_vseq)

  function new(string name = "uart_apb_debug_overrun_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] data;
    configure_uart(16, 6'b00_0010);
    uart_send(8'h11);
    uart_send(8'h22);
    apb_read(UART_STATUS_ADDR, data);
    if (!data[STATUS_RX_OVERRUN_BIT]) begin
      `uvm_error(get_type_name(), "RX_OVERRUN was not asserted")
    end
    apb_read(UART_DATA_ADDR, data);
    if (data[7:0] !== 8'h11) begin
      `uvm_error(get_type_name(),
        $sformatf("Overrun must preserve 0x11, got 0x%02h", data[7:0]))
    end
  endtask
endclass

class uart_apb_debug_frame_error_vseq extends uart_apb_base_vseq;
  `uvm_object_utils(uart_apb_debug_frame_error_vseq)

  function new(string name = "uart_apb_debug_frame_error_vseq");
    super.new(name);
  endfunction

  task body();
    logic [31:0] first_status;
    logic [31:0] second_status;
    logic [31:0] cleared_status;
    configure_uart(16, 6'b00_0010);
    uart_send(8'h5a, 1'b1);
    // uart_send returns after the complete stop-bit interval, so the first
    // explicit STATUS read below is the read that must preserve FRAME_ERR.
    apb_read(UART_STATUS_ADDR, first_status);
    apb_read(UART_STATUS_ADDR, second_status);
    if (!first_status[STATUS_FRAME_ERR_BIT] ||
        !second_status[STATUS_FRAME_ERR_BIT]) begin
      `uvm_error(get_type_name(),
        $sformatf("FRAME_ERR must be sticky: first=0x%02h second=0x%02h",
                  first_status[7:0], second_status[7:0]))
    end
    apb_write(UART_CTRL_ADDR, 32'h0000_0100, 4'b0010);
    apb_read(UART_STATUS_ADDR, cleared_status);
    if (cleared_status[STATUS_FRAME_ERR_BIT]) begin
      `uvm_error(get_type_name(), "CLR_ERRORS failed to clear FRAME_ERR")
    end
  endtask
endclass
