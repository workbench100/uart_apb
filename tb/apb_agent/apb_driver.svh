class apb_driver extends uvm_driver #(apb_item);
  `uvm_component_utils(apb_driver)

  apb_agent_config cfg;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(apb_agent_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "apb_agent_config was not supplied")
    end
  endfunction

  task run_phase(uvm_phase phase);
    apb_item req;
    apb_item rsp;

    drive_idle();
    forever begin
      seq_item_port.get_next_item(req);
      rsp = apb_item::type_id::create("rsp");
      rsp.set_id_info(req);
      drive_transfer(req, rsp);
      seq_item_port.item_done(rsp);
    end
  endtask

  task drive_idle();
    cfg.vif.drv_cb.PADDR   <= '0;
    cfg.vif.drv_cb.PSEL    <= 1'b0;
    cfg.vif.drv_cb.PENABLE <= 1'b0;
    cfg.vif.drv_cb.PWRITE  <= 1'b0;
    cfg.vif.drv_cb.PWDATA  <= '0;
    cfg.vif.drv_cb.PSTRB   <= '0;
  endtask

  task drive_transfer(apb_item req, ref apb_item rsp);
    wait (cfg.vif.PRESETn === 1'b1);
    repeat (req.idle_cycles) @(cfg.vif.drv_cb);

    @(cfg.vif.drv_cb);
    cfg.vif.drv_cb.PADDR   <= req.apb_addr;
    cfg.vif.drv_cb.PWRITE  <= (req.direction == APB_WRITE);
    cfg.vif.drv_cb.PWDATA  <= req.write_data;
    cfg.vif.drv_cb.PSTRB   <= req.strb;
    cfg.vif.drv_cb.PSEL    <= 1'b1;
    cfg.vif.drv_cb.PENABLE <= 1'b0;

    @(cfg.vif.drv_cb);
    cfg.vif.drv_cb.PENABLE <= 1'b1;

    rsp.apb_addr    = req.apb_addr;
    rsp.write_data  = req.write_data;
    rsp.direction   = req.direction;
    rsp.strb        = req.strb;
    rsp.idle_cycles = req.idle_cycles;
    rsp.wait_cycles = 0;
    rsp.aborted     = 1'b0;

    forever begin
      @(cfg.vif.drv_cb);
      if (cfg.vif.drv_cb.PRESETn !== 1'b1) begin
        rsp.aborted = 1'b1;
        rsp.slverr  = 1'b1;
        drive_idle();
        break;
      end
      if (cfg.vif.drv_cb.PREADY === 1'b1) begin
        rsp.read_data = cfg.vif.drv_cb.PRDATA;
        rsp.slverr    = cfg.vif.drv_cb.PSLVERR;
        drive_idle();
        break;
      end
      rsp.wait_cycles++;
    end
  endtask
endclass
