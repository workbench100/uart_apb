class uart_apb_env extends uvm_env;
  `uvm_component_utils(uart_apb_env)

  uart_apb_env_config cfg;
  apb_agent           apb_agt;
  uart_agent          uart_agt;
  uart_apb_scoreboard scoreboard;
  uart_apb_reg_block  regmodel;
  uart_apb_reg_adapter reg_adapter;
  uvm_reg_predictor #(apb_item) reg_predictor;
  uart_apb_virtual_sequencer virtual_sequencer;

  function new(string name = "uart_apb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_apb_env_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "uart_apb_env_config was not supplied")
    end

    uvm_config_db#(apb_agent_config)::set(this, "apb_agt", "cfg", cfg.apb_cfg);
    uvm_config_db#(uart_agent_config)::set(this, "uart_agt", "cfg", cfg.uart_cfg);
    apb_agt  = apb_agent::type_id::create("apb_agt", this);
    uart_agt = uart_agent::type_id::create("uart_agt", this);

    virtual_sequencer = uart_apb_virtual_sequencer::type_id::create(
      "virtual_sequencer", this);

    if (cfg.scoreboard_enable) begin
      uvm_config_db#(uart_apb_env_config)::set(this, "scoreboard", "cfg", cfg);
      scoreboard = uart_apb_scoreboard::type_id::create("scoreboard", this);
    end

    if (cfg.ral_enable) begin
      regmodel = uart_apb_reg_block::type_id::create("regmodel");
      regmodel.build();
      regmodel.reset();
      reg_adapter   = uart_apb_reg_adapter::type_id::create("reg_adapter");
      reg_predictor = uvm_reg_predictor#(apb_item)::type_id::create(
        "reg_predictor", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    virtual_sequencer.apb_sqr   = apb_agt.sequencer;
    virtual_sequencer.uart_sqr  = uart_agt.sequencer;
    virtual_sequencer.reset_vif = cfg.reset_vif;

    if (cfg.scoreboard_enable) begin
      apb_agt.monitor.ap.connect(scoreboard.apb_imp);
      uart_agt.monitor.ap.connect(scoreboard.uart_tx_imp);
      if (cfg.uart_cfg.is_active == UVM_ACTIVE) begin
        uart_agt.driver.sent_ap.connect(scoreboard.uart_rx_imp);
      end
    end

    if (cfg.ral_enable) begin
      regmodel.default_map.set_sequencer(apb_agt.sequencer, reg_adapter);
      regmodel.default_map.set_auto_predict(0);
      reg_predictor.map     = regmodel.default_map;
      reg_predictor.adapter = reg_adapter;
      apb_agt.monitor.ap.connect(reg_predictor.bus_in);
      virtual_sequencer.regmodel = regmodel;
    end
  endfunction
endclass
