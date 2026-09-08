class uart_coverage extends uvm_subscriber #(uart_item);
  `uvm_component_utils(uart_coverage)

  uart_item sample_item;

  covergroup uart_cg;
    option.per_instance = 1;

    cp_data: coverpoint sample_item.data {
      bins all_zero     = {8'h00};
      bins all_one      = {8'hff};
      bins walking_one  = {8'h01, 8'h02, 8'h04, 8'h08,
                           8'h10, 8'h20, 8'h40, 8'h80};
      bins walking_zero = {8'hfe, 8'hfd, 8'hfb, 8'hf7,
                           8'hef, 8'hdf, 8'hbf, 8'h7f};
      bins other        = default;
    }
    cp_frame_error: coverpoint (sample_item.observed_frame_error ||
                                sample_item.inject_bad_stop);
    cp_bit_cycles: coverpoint sample_item.bit_cycles {
      bins minimum = {2};
      bins small   = {[3:8]};
      bins medium  = {[9:32]};
      bins large   = {[33:65535]};
    }
    cx_data_error: cross cp_data, cp_frame_error;
  endgroup

  function new(string name = "uart_coverage", uvm_component parent = null);
    super.new(name, parent);
    uart_cg = new();
  endfunction

  function void write(uart_item t);
    sample_item = t;
    uart_cg.sample();
  endfunction
endclass
