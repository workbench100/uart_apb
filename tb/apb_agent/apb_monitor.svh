class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  apb_agent_config cfg;
  uvm_analysis_port #(apb_item) ap;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(apb_agent_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "apb_agent_config was not supplied")
    end
  endfunction

  task run_phase(uvm_phase phase);
    apb_item tr;
    bit pending;
    int unsigned waits;

    pending = 1'b0;
    waits   = 0;
    forever begin
      @(cfg.vif.mon_cb);
      if (cfg.vif.mon_cb.PRESETn !== 1'b1) begin
        pending = 1'b0;
        waits   = 0;
        continue;
      end

      if (cfg.vif.mon_cb.PSEL && !cfg.vif.mon_cb.PENABLE) begin
        pending = 1'b1;
        waits   = 0;
      end

      if (pending && cfg.vif.mon_cb.PSEL && cfg.vif.mon_cb.PENABLE) begin
        if (cfg.vif.mon_cb.PREADY) begin
          tr = apb_item::type_id::create("tr", this);
          tr.apb_addr    = cfg.vif.mon_cb.PADDR;
          tr.direction   = cfg.vif.mon_cb.PWRITE ? APB_WRITE : APB_READ;
          tr.write_data  = cfg.vif.mon_cb.PWDATA;
          tr.strb        = cfg.vif.mon_cb.PSTRB;
          tr.read_data   = cfg.vif.mon_cb.PRDATA;
          tr.slverr      = cfg.vif.mon_cb.PSLVERR;
          tr.wait_cycles = waits;
          tr.aborted     = 1'b0;
          ap.write(tr);
          pending = 1'b0;
        end else begin
          waits++;
        end
      end
    end
  endtask
endclass
