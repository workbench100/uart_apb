package uart_apb_regs_pkg;

  localparam logic [11:0] UART_DATA_ADDR       = 12'h000;
  localparam logic [11:0] UART_STATUS_ADDR     = 12'h004;
  localparam logic [11:0] UART_CTRL_ADDR       = 12'h008;
  localparam logic [11:0] UART_BAUD_DIV_ADDR   = 12'h00c;
  localparam logic [11:0] UART_IRQ_STATUS_ADDR = 12'h010;
  localparam logic [11:0] UART_SCRATCH_ADDR    = 12'h014;

  localparam int unsigned STATUS_TX_BUSY_BIT    = 0;
  localparam int unsigned STATUS_TX_READY_BIT   = 1;
  localparam int unsigned STATUS_RX_VALID_BIT   = 2;
  localparam int unsigned STATUS_RX_OVERRUN_BIT = 3;
  localparam int unsigned STATUS_FRAME_ERR_BIT  = 4;

  localparam int unsigned CTRL_TX_EN_BIT      = 0;
  localparam int unsigned CTRL_RX_EN_BIT      = 1;
  localparam int unsigned CTRL_RX_IRQ_EN_BIT  = 2;
  localparam int unsigned CTRL_ERR_IRQ_EN_BIT = 3;
  localparam int unsigned CTRL_TX_IRQ_EN_BIT  = 4;
  localparam int unsigned CTRL_LOOPBACK_BIT   = 5;
  localparam int unsigned CTRL_CLR_ERRORS_BIT = 8;

  localparam int unsigned IRQ_RX_BIT      = 0;
  localparam int unsigned IRQ_ERR_BIT     = 1;
  localparam int unsigned IRQ_TX_DONE_BIT = 2;

endpackage
