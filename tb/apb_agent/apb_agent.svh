class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_agent_config cfg;
  apb_sequencer    sequencer;
  apb_driver       driver;
  apb_monitor      monitor;
  apb_coverage     coverage;

  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(apb_agent_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "apb_agent_config was not supplied")
    end

    uvm_config_db#(apb_agent_config)::set(this, "monitor", "cfg", cfg);
    monitor = apb_monitor::type_id::create("monitor", this);

    if (cfg.coverage_enable) begin
      coverage = apb_coverage::type_id::create("coverage", this);
    end

    if (cfg.is_active == UVM_ACTIVE) begin
      uvm_config_db#(apb_agent_config)::set(this, "driver", "cfg", cfg);
      sequencer = apb_sequencer::type_id::create("sequencer", this);
      driver    = apb_driver::type_id::create("driver", this);
      sequencer.vif = cfg.vif;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
    if (cfg.coverage_enable) begin
      monitor.ap.connect(coverage.analysis_export);
    end
  endfunction
endclass
