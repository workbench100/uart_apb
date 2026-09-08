class apb_single_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_single_seq)

  apb_direction_e direction = APB_READ;
  logic [11:0]    apb_addr  = '0;
  logic [31:0]    write_data = '0;
  logic [3:0]     strb = 4'hf;
  int unsigned    idle_cycles = 0;

  logic [31:0]    read_data;
  bit             slverr;
  bit             aborted;
  int unsigned    wait_cycles;

  function new(string name = "apb_single_seq");
    super.new(name);
  endfunction

  task body();
    apb_item req;
    apb_item rsp;

    req = apb_item::type_id::create("req");
    start_item(req);
    req.direction   = direction;
    req.apb_addr    = apb_addr;
    req.write_data  = write_data;
    req.strb        = (direction == APB_READ) ? 4'h0 : strb;
    req.idle_cycles = idle_cycles;
    finish_item(req);

    get_response(rsp);
    read_data   = rsp.read_data;
    slverr      = rsp.slverr;
    aborted     = rsp.aborted;
    wait_cycles = rsp.wait_cycles;
  endtask
endclass

class apb_random_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_random_seq)

  int unsigned transfer_count = 50;

  function new(string name = "apb_random_seq");
    super.new(name);
  endfunction

  task body();
    apb_item req;
    apb_item rsp;
    repeat (transfer_count) begin
      `uvm_do(req)
      get_response(rsp);
    end
  endtask
endclass
