class uart_tx_monitor extends uvm_monitor;
  `uvm_component_utils(uart_tx_monitor)

  uart_agent_config cfg;
  uvm_analysis_port #(uart_item) ap;

  function new(string name = "uart_tx_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_agent_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "uart_agent_config was not supplied")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_item tr;
    int unsigned cycles;
    int unsigned half_cycles;
    bit reset_seen;

    forever begin
      wait (cfg.vif.reset_n === 1'b1);
      @(negedge cfg.vif.tx);
      if (cfg.vif.reset_n !== 1'b1) begin
        continue;
      end

      cycles      = cfg.bit_cycles;
      half_cycles = cycles / 2;
      if (half_cycles == 0) begin
        half_cycles = 1;
      end

      tr = uart_item::type_id::create("tr", this);
      tr.bit_cycles = cycles;
      tr.idle_bits  = 1;

      wait_cycles_or_reset(half_cycles, reset_seen);
      if (reset_seen) begin
        continue;
      end
      tr.observed_start_error = (cfg.vif.mon_cb.tx !== 1'b0);
      if (tr.observed_start_error) begin
        if (cfg.checks_enable) begin
          `uvm_error(get_type_name(), "False or malformed UART TX start bit")
        end
        continue;
      end

      for (int bit_index = 0; bit_index < 8; bit_index++) begin
        wait_cycles_or_reset(cycles, reset_seen);
        if (reset_seen) begin
          break;
        end
        tr.data[bit_index] = cfg.vif.mon_cb.tx;
      end
      if (reset_seen) begin
        continue;
      end

      wait_cycles_or_reset(cycles, reset_seen);
      if (reset_seen) begin
        continue;
      end
      tr.observed_frame_error = (cfg.vif.mon_cb.tx !== 1'b1);
      ap.write(tr);
    end
  endtask

  task wait_cycles_or_reset(input int unsigned count,
                            output bit reset_seen);
    reset_seen = 1'b0;
    if (cfg.vif.reset_n !== 1'b1) begin
      reset_seen = 1'b1;
      return;
    end
    fork : wait_or_reset
      begin
        repeat (count) @(cfg.vif.mon_cb);
      end
      begin
        @(negedge cfg.vif.reset_n);
        reset_seen = 1'b1;
      end
    join_any
    disable wait_or_reset;
  endtask
endclass
