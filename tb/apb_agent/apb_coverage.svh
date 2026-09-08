class apb_coverage extends uvm_subscriber #(apb_item);
  `uvm_component_utils(apb_coverage)

  apb_item sample_item;

  covergroup apb_cg;
    option.per_instance = 1;

    cp_direction: coverpoint sample_item.direction;
    cp_address: coverpoint sample_item.apb_addr {
      bins data       = {12'h000};
      bins status     = {12'h004};
      bins ctrl       = {12'h008};
      bins baud_div   = {12'h00c};
      bins irq_status = {12'h010};
      bins scratch    = {12'h014};
      bins other      = default;
    }
    cp_alignment: coverpoint sample_item.apb_addr[1:0] {
      bins aligned   = {2'b00};
      bins unaligned = default;
    }
    cp_strb: coverpoint sample_item.strb iff (sample_item.direction == APB_WRITE) {
      bins none        = {4'b0000};
      bins full        = {4'b1111};
      bins single[]    = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
      bins partial     = default;
    }
    cp_error: coverpoint sample_item.slverr;
    cp_wait: coverpoint sample_item.wait_cycles {
      bins zero  = {0};
      bins one   = {1};
      bins short = {[2:3]};
      bins long  = {[4:$]};
    }
    cx_addr_dir_err: cross cp_address, cp_direction, cp_error;
  endgroup

  function new(string name = "apb_coverage", uvm_component parent = null);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  function void write(apb_item t);
    sample_item = t;
    apb_cg.sample();
  endfunction
endclass
