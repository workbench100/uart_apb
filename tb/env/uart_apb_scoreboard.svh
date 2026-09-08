`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_uart_tx)
`uvm_analysis_imp_decl(_uart_rx)

class uart_apb_scoreboard extends uvm_component;
  `uvm_component_utils(uart_apb_scoreboard)

  uvm_analysis_imp_apb     #(apb_item,  uart_apb_scoreboard) apb_imp;
  uvm_analysis_imp_uart_tx #(uart_item, uart_apb_scoreboard) uart_tx_imp;
  uvm_analysis_imp_uart_rx #(uart_item, uart_apb_scoreboard) uart_rx_imp;

  uart_apb_env_config cfg;

  logic [5:0]  ctrl_model;
  logic [15:0] baud_div_model;
  logic [31:0] scratch_model;
  logic [7:0]  rx_data_model;
  bit          rx_valid_model;
  bit          rx_overrun_model;
  bit          frame_error_model;
  logic [2:0]  irq_status_model;
  logic [7:0]  expected_tx_queue[$];
  logic [7:0]  pending_loopback_queue[$];
  int unsigned pending_loopback_delay[$];

  int unsigned scenario_event;
  int unsigned tx_compared;
  int unsigned rx_compared;

  covergroup scenario_cg;
    option.per_instance = 1;
    cp_mode: coverpoint ctrl_model[1:0] {
      bins disabled = {2'b00};
      bins tx_only  = {2'b01};
      bins rx_only  = {2'b10};
      bins full_duplex = {2'b11};
    }
    cp_loopback: coverpoint ctrl_model[5];
    cp_event: coverpoint scenario_event {
      bins apb_tx        = {0};
      bins rx_store      = {1};
      bins rx_overrun    = {2};
      bins frame_error   = {3};
      bins loopback_rx   = {4};
      bins error_clear   = {5};
    }
    cx_mode_event: cross cp_mode, cp_event;
  endgroup

  function new(string name = "uart_apb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    apb_imp     = new("apb_imp", this);
    uart_tx_imp = new("uart_tx_imp", this);
    uart_rx_imp = new("uart_rx_imp", this);
    scenario_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_apb_env_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "uart_apb_env_config was not supplied")
    end
    reset_model();
  endfunction

  task run_phase(uvm_phase phase);
    fork
      forever begin
        @(negedge cfg.reset_vif.reset_n);
        reset_model();
      end
      forever begin
        @(posedge cfg.reset_vif.clk);
        if (cfg.reset_vif.reset_n && pending_loopback_delay.size() != 0) begin
          if (pending_loopback_delay[0] == 0) begin
            void'(pending_loopback_delay.pop_front());
            accept_rx_frame(pending_loopback_queue.pop_front(), 1'b0, 1'b1);
          end else begin
            pending_loopback_delay[0]--;
          end
        end
      end
    join
  endtask

  function void reset_model();
    ctrl_model        = '0;
    baud_div_model    = 16;
    scratch_model     = '0;
    rx_data_model     = '0;
    rx_valid_model    = 1'b0;
    rx_overrun_model  = 1'b0;
    frame_error_model = 1'b0;
    irq_status_model  = '0;
    expected_tx_queue.delete();
    pending_loopback_queue.delete();
    pending_loopback_delay.delete();
    if (cfg != null && cfg.uart_cfg != null) begin
      cfg.uart_cfg.bit_cycles = 16;
    end
  endfunction

  function automatic logic [31:0] merge_by_strb(
    input logic [31:0] old_value,
    input logic [31:0] new_value,
    input logic [3:0]  strb
  );
    logic [31:0] merged;
    merged = old_value;
    for (int index = 0; index < 4; index++) begin
      if (strb[index]) begin
        merged[index*8 +: 8] = new_value[index*8 +: 8];
      end
    end
    return merged;
  endfunction

  function void sample_scenario(int unsigned event_kind);
    scenario_event = event_kind;
    scenario_cg.sample();
  endfunction

  function void write_apb(apb_item tr);
    logic [31:0] expected;
    logic [31:0] merged;
    logic [31:0] compare_mask;

    if (tr.aborted || tr.slverr) begin
      return;
    end

    if (tr.direction == APB_WRITE) begin
      case (tr.apb_addr)
        UART_DATA_ADDR: begin
          expected_tx_queue.push_back(tr.write_data[7:0]);
          sample_scenario(0);
        end

        UART_CTRL_ADDR: begin
          if (tr.strb[0]) begin
            ctrl_model = tr.write_data[5:0];
          end
          if (tr.strb[1] && tr.write_data[CTRL_CLR_ERRORS_BIT]) begin
            rx_overrun_model  = 1'b0;
            frame_error_model = 1'b0;
            sample_scenario(5);
          end
        end

        UART_BAUD_DIV_ADDR: begin
          merged = merge_by_strb({16'h0000, baud_div_model},
                                 tr.write_data, tr.strb);
          baud_div_model = merged[15:0];
          cfg.uart_cfg.bit_cycles = baud_div_model;
        end

        UART_IRQ_STATUS_ADDR: begin
          if (tr.strb[0]) begin
            irq_status_model &= ~tr.write_data[2:0];
          end
        end

        UART_SCRATCH_ADDR: begin
          scratch_model = merge_by_strb(scratch_model,
                                        tr.write_data, tr.strb);
        end

        default: begin
        end
      endcase
    end else begin
      case (tr.apb_addr)
        UART_DATA_ADDR: begin
          expected = rx_valid_model ? {24'h0, rx_data_model} : 32'h0;
          if (tr.read_data !== expected) begin
            `uvm_error(get_type_name(),
              $sformatf("DATA mismatch: expected 0x%08h, got 0x%08h",
                        expected, tr.read_data))
          end else if (rx_valid_model) begin
            rx_compared++;
          end
          rx_valid_model = 1'b0;
        end

        UART_STATUS_ADDR: begin
          expected = '0;
          compare_mask = 32'h0000_001c;
          expected[STATUS_RX_VALID_BIT]   = rx_valid_model;
          expected[STATUS_RX_OVERRUN_BIT] = rx_overrun_model;
          expected[STATUS_FRAME_ERR_BIT]  = frame_error_model;
          // Allow the known two-to-three-clock observation skew between the
          // TX stop-bit monitor and the internal loopback RX commit.
          if (pending_loopback_queue.size() != 0) begin
            compare_mask[STATUS_RX_VALID_BIT] = 1'b0;
          end
          if ((tr.read_data & compare_mask) !==
              (expected     & compare_mask)) begin
            `uvm_error(get_type_name(),
              $sformatf("STATUS mismatch on RX/error bits: expected 0x%02h, got 0x%02h",
                        expected[7:0], tr.read_data[7:0]))
          end
        end

        UART_CTRL_ADDR: begin
          if (tr.read_data[5:0] !== ctrl_model) begin
            `uvm_error(get_type_name(),
              $sformatf("CTRL mismatch: expected 0x%02h, got 0x%02h",
                        ctrl_model, tr.read_data[5:0]))
          end
        end

        UART_BAUD_DIV_ADDR: begin
          if (tr.read_data !== {16'h0000, baud_div_model}) begin
            `uvm_error(get_type_name(),
              $sformatf("BAUD_DIV mismatch: expected %0d, got 0x%08h",
                        baud_div_model, tr.read_data))
          end
        end

        UART_IRQ_STATUS_ADDR: begin
          if (tr.read_data[2:0] !== irq_status_model) begin
            `uvm_error(get_type_name(),
              $sformatf("IRQ_STATUS mismatch: expected 0x%0h, got 0x%0h",
                        irq_status_model, tr.read_data[2:0]))
          end
        end

        UART_SCRATCH_ADDR: begin
          if (tr.read_data !== scratch_model) begin
            `uvm_error(get_type_name(),
              $sformatf("SCRATCH mismatch: expected 0x%08h, got 0x%08h",
                        scratch_model, tr.read_data))
          end
        end

        default: begin
        end
      endcase
    end
  endfunction

  function void accept_rx_frame(logic [7:0] data,
                                bit bad_stop,
                                bit from_loopback);
    if (!ctrl_model[CTRL_RX_EN_BIT]) begin
      return;
    end

    if (rx_valid_model) begin
      rx_overrun_model = 1'b1;
      irq_status_model[IRQ_ERR_BIT] = 1'b1;
      sample_scenario(2);
    end else begin
      rx_data_model  = data;
      rx_valid_model = 1'b1;
      irq_status_model[IRQ_RX_BIT] = 1'b1;
      sample_scenario(from_loopback ? 4 : 1);
    end

    if (bad_stop) begin
      frame_error_model = 1'b1;
      irq_status_model[IRQ_ERR_BIT] = 1'b1;
      sample_scenario(3);
    end
  endfunction

  function void write_uart_rx(uart_item tr);
    if (ctrl_model[CTRL_LOOPBACK_BIT]) begin
      return;
    end
    accept_rx_frame(tr.data, tr.inject_bad_stop, 1'b0);
  endfunction

  function void write_uart_tx(uart_item tr);
    logic [7:0] expected_byte;

    if (expected_tx_queue.size() == 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Unexpected UART TX byte 0x%02h", tr.data))
      return;
    end

    expected_byte = expected_tx_queue.pop_front();
    if (tr.data !== expected_byte) begin
      `uvm_error(get_type_name(),
        $sformatf("UART TX mismatch: expected 0x%02h, got 0x%02h",
                  expected_byte, tr.data))
    end else begin
      tx_compared++;
    end

    if (tr.observed_frame_error) begin
      `uvm_error(get_type_name(), "DUT UART TX emitted an invalid stop bit")
    end

    irq_status_model[IRQ_TX_DONE_BIT] = 1'b1;
    if (ctrl_model[CTRL_LOOPBACK_BIT]) begin
      // The TX monitor samples at the center of the stop bit. The DUT RX path
      // commits the looped-back byte a few PCLK edges later.
      pending_loopback_queue.push_back(tr.data);
      pending_loopback_delay.push_back(2);
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (expected_tx_queue.size() != 0) begin
      `uvm_error(get_type_name(),
        $sformatf("%0d expected UART TX byte(s) were not observed",
                  expected_tx_queue.size()))
    end
    if (pending_loopback_queue.size() != 0) begin
      `uvm_error(get_type_name(),
        $sformatf("%0d loopback byte(s) were not committed to the RX model",
                  pending_loopback_queue.size()))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(),
      $sformatf("End-to-end comparisons: TX=%0d RX=%0d",
                tx_compared, rx_compared), UVM_LOW)
  endfunction
endclass
