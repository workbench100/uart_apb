class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uart_agent_config cfg;
  uart_sequencer    sequencer;
  uart_rx_driver    driver;
  uart_tx_monitor   monitor;
  uart_coverage     coverage;

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_agent_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "uart_agent_config was not supplied")
    end

    uvm_config_db#(uart_agent_config)::set(this, "monitor", "cfg", cfg);
    monitor = uart_tx_monitor::type_id::create("monitor", this);

    if (cfg.coverage_enable) begin
      coverage = uart_coverage::type_id::create("coverage", this);
    end

    if (cfg.is_active == UVM_ACTIVE) begin
      uvm_config_db#(uart_agent_config)::set(this, "driver", "cfg", cfg);
      sequencer = uart_sequencer::type_id::create("sequencer", this);
      driver    = uart_rx_driver::type_id::create("driver", this);
      sequencer.vif = cfg.vif;
      sequencer.cfg = cfg;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
    if (cfg.coverage_enable) begin
      monitor.ap.connect(coverage.analysis_export);
      if (cfg.is_active == UVM_ACTIVE) begin
        driver.sent_ap.connect(coverage.analysis_export);
      end
    end
  endfunction
endclass
