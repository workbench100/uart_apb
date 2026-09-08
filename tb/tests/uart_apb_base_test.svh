class uart_apb_base_test extends uvm_test;
  `uvm_component_utils(uart_apb_base_test)

  uart_apb_env        env;
  uart_apb_env_config env_cfg;
  apb_agent_config    apb_cfg;
  uart_agent_config   uart_cfg;

  virtual apb_if   apb_vif;
  virtual uart_if  uart_vif;
  virtual reset_if reset_vif;

  function new(string name = "uart_apb_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", apb_vif)) begin
      `uvm_fatal(get_type_name(), "apb_vif was not supplied by tb_top")
    end
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", uart_vif)) begin
      `uvm_fatal(get_type_name(), "uart_vif was not supplied by tb_top")
    end
    if (!uvm_config_db#(virtual reset_if)::get(this, "", "reset_vif", reset_vif)) begin
      `uvm_fatal(get_type_name(), "reset_vif was not supplied by tb_top")
    end

    apb_cfg = apb_agent_config::type_id::create("apb_cfg");
    apb_cfg.vif = apb_vif;
    apb_cfg.is_active = UVM_ACTIVE;

    uart_cfg = uart_agent_config::type_id::create("uart_cfg");
    uart_cfg.vif = uart_vif;
    uart_cfg.is_active = UVM_ACTIVE;
    uart_cfg.bit_cycles = 16;

    env_cfg = uart_apb_env_config::type_id::create("env_cfg");
    env_cfg.apb_cfg   = apb_cfg;
    env_cfg.uart_cfg  = uart_cfg;
    env_cfg.reset_vif = reset_vif;

    uvm_config_db#(uart_apb_env_config)::set(this, "env", "cfg", env_cfg);
    env = uart_apb_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait (reset_vif.reset_n === 1'b1);
    @(posedge apb_vif.PCLK);
    run_main_sequence();
    repeat (20) @(posedge apb_vif.PCLK);
    phase.drop_objection(this);
  endtask

  virtual task run_main_sequence();
    uart_apb_smoke_vseq seq;
    seq = uart_apb_smoke_vseq::type_id::create("seq");
    seq.start(env.virtual_sequencer);
  endtask
endclass
