class uart_send_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_send_seq)

  logic [7:0] data = 8'h00;
  int unsigned bit_cycles = 16;
  int unsigned idle_bits = 1;
  bit inject_bad_stop = 1'b0;

  function new(string name = "uart_send_seq");
    super.new(name);
  endfunction

  task body();
    uart_item req;
    req = uart_item::type_id::create("req");
    start_item(req);
    req.data            = data;
    req.bit_cycles      = bit_cycles;
    req.idle_bits       = idle_bits;
    req.inject_bad_stop = inject_bad_stop;
    finish_item(req);
  endtask
endclass

class uart_random_seq extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_random_seq)

  int unsigned frame_count = 20;
  int unsigned configured_bit_cycles = 16;
  bit allow_bad_stop = 1'b0;

  function new(string name = "uart_random_seq");
    super.new(name);
  endfunction

  task body();
    uart_item req;
    repeat (frame_count) begin
      req = uart_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with {
        bit_cycles == local::configured_bit_cycles;
        if (!local::allow_bad_stop) inject_bad_stop == 1'b0;
      }) begin
        `uvm_fatal(get_type_name(), "Failed to randomize UART frame")
      end
      finish_item(req);
    end
  endtask
endclass
