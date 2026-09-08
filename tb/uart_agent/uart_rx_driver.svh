class uart_rx_driver extends uvm_driver #(uart_item);
  `uvm_component_utils(uart_rx_driver)

  uart_agent_config cfg;
  uvm_analysis_port #(uart_item) sent_ap;

  function new(string name = "uart_rx_driver", uvm_component parent = null);
    super.new(name, parent);
    sent_ap = new("sent_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_agent_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "uart_agent_config was not supplied")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_item req;
    uart_item sent;
    bit aborted;

    cfg.vif.drv_cb.rx <= 1'b1;
    forever begin
      seq_item_port.get_next_item(req);
      drive_frame(req, aborted);
      if (!aborted) begin
        $cast(sent, req.clone());
        sent_ap.write(sent);
      end else begin
        `uvm_info(get_type_name(), "UART RX frame aborted by reset", UVM_MEDIUM)
      end
      seq_item_port.item_done();
    end
  endtask

  task drive_frame(uart_item req, output bit aborted);
    int unsigned cycles;

    aborted = 1'b0;
    wait (cfg.vif.reset_n === 1'b1);
    cycles = (req.bit_cycles == 0) ? cfg.bit_cycles : req.bit_cycles;
    if (cycles < 2) begin
      `uvm_fatal(get_type_name(), $sformatf("Illegal UART bit_cycles=%0d", cycles))
    end

    hold_level_or_reset(1'b1, req.idle_bits * cycles, aborted);
    if (aborted) return;

    hold_level_or_reset(1'b0, cycles, aborted);
    if (aborted) return;

    for (int bit_index = 0; bit_index < 8; bit_index++) begin
      hold_level_or_reset(req.data[bit_index], cycles, aborted);
      if (aborted) return;
    end

    hold_level_or_reset(req.inject_bad_stop ? 1'b0 : 1'b1,
                        cycles, aborted);
    if (aborted) return;
    hold_level_or_reset(1'b1, 1, aborted);
  endtask

  task hold_level_or_reset(input logic level,
                           input int unsigned count,
                           output bit reset_seen);
    reset_seen = 1'b0;
    cfg.vif.drv_cb.rx <= level;
    if (cfg.vif.reset_n !== 1'b1) begin
      reset_seen = 1'b1;
      cfg.vif.drv_cb.rx <= 1'b1;
      return;
    end
    fork : wait_or_reset
      begin
        repeat (count) @(cfg.vif.drv_cb);
      end
      begin
        @(negedge cfg.vif.reset_n);
        reset_seen = 1'b1;
      end
    join_any
    disable wait_or_reset;
    if (reset_seen) begin
      cfg.vif.drv_cb.rx <= 1'b1;
    end
  endtask
endclass
