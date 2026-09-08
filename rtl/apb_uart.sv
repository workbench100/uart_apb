`timescale 1ns/1ps

module apb_uart #(
  parameter int unsigned ADDR_WIDTH     = 12,
  parameter int unsigned DATA_WIDTH     = 32,
  parameter int unsigned RESET_BAUD_DIV = 16,
  // bit 0: SCRATCH ignores PSTRB
  // bit 1: RX overrun overwrites the holding byte
  // bit 2: STATUS read clears FRAME_ERR
  parameter logic [2:0]  BUG_MASK       = 3'b111
) (
  input  logic                      PCLK,
  input  logic                      PRESETn,
  input  logic [ADDR_WIDTH-1:0]     PADDR,
  input  logic                      PSEL,
  input  logic                      PENABLE,
  input  logic                      PWRITE,
  input  logic [DATA_WIDTH-1:0]     PWDATA,
  input  logic [(DATA_WIDTH/8)-1:0] PSTRB,
  output logic [DATA_WIDTH-1:0]     PRDATA,
  output logic                      PREADY,
  output logic                      PSLVERR,
  input  logic                      uart_rx,
  output logic                      uart_tx,
  output logic                      irq
);

  import uart_apb_regs_pkg::*;

`ifndef SYNTHESIS
  initial begin
    if (DATA_WIDTH != 32) begin
      $fatal(1, "apb_uart currently requires DATA_WIDTH=32");
    end
    if (ADDR_WIDTH < 12) begin
      $fatal(1, "apb_uart requires ADDR_WIDTH>=12");
    end
    if ((RESET_BAUD_DIV < 2) || (RESET_BAUD_DIV > 65535)) begin
      $fatal(1, "RESET_BAUD_DIV must be in the range 2..65535");
    end
  end
`endif

  typedef enum logic [1:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_STOP
  } tx_state_e;

  typedef enum logic [1:0] {
    RX_IDLE,
    RX_START,
    RX_DATA,
    RX_STOP
  } rx_state_e;

  logic [5:0]  ctrl_q;
  logic [15:0] baud_div_q;
  logic [31:0] scratch_q;
  logic [7:0]  rx_data_q;
  logic        rx_valid_q;
  logic        rx_overrun_q;
  logic        frame_error_q;
  logic [2:0]  irq_status_q;

  tx_state_e   tx_state_q;
  logic [7:0]  tx_shift_q;
  logic [2:0]  tx_bit_index_q;
  logic [15:0] tx_count_q;
  logic [15:0] tx_div_latched_q;
  logic        tx_busy_q;
  logic        tx_q;
  logic        tx_done_event;

  rx_state_e   rx_state_q;
  logic [7:0]  rx_shift_q;
  logic [2:0]  rx_bit_index_q;
  logic [15:0] rx_count_q;
  logic [15:0] rx_div_latched_q;
  logic        rx_byte_event;
  logic [7:0]  rx_event_data;
  logic        rx_frame_error_event;

  logic [15:0] merged_baud_div;
  logic        apb_access;
  logic        apb_commit;
  logic        data_write_start;
  logic        data_read_pop;
  logic        status_read;
  logic        ctrl_clear_errors;
  logic        rx_sample;

  integer byte_index;

  assign uart_tx  = tx_q;
  assign rx_sample = ctrl_q[CTRL_LOOPBACK_BIT] ? tx_q : uart_rx;

  assign irq = (ctrl_q[CTRL_RX_IRQ_EN_BIT]  && irq_status_q[IRQ_RX_BIT])      ||
               (ctrl_q[CTRL_ERR_IRQ_EN_BIT] && irq_status_q[IRQ_ERR_BIT])     ||
               (ctrl_q[CTRL_TX_IRQ_EN_BIT]  && irq_status_q[IRQ_TX_DONE_BIT]);

  always_comb begin
    merged_baud_div = baud_div_q;
    if (PSTRB[0]) begin
      merged_baud_div[7:0] = PWDATA[7:0];
    end
    if (PSTRB[1]) begin
      merged_baud_div[15:8] = PWDATA[15:8];
    end
  end

  always_comb begin
    PREADY  = 1'b1;
    PRDATA  = '0;
    PSLVERR = 1'b0;

    if (PSEL && PENABLE) begin
      if (PADDR[1:0] != 2'b00) begin
        PSLVERR = 1'b1;
      end else begin
        case (PADDR)
          UART_DATA_ADDR: begin
            if (PWRITE) begin
              if (!PSTRB[0] || !ctrl_q[CTRL_TX_EN_BIT] || tx_busy_q) begin
                PSLVERR = 1'b1;
              end
            end else begin
              PRDATA[7:0] = rx_valid_q ? rx_data_q : 8'h00;
            end
          end

          UART_STATUS_ADDR: begin
            if (PWRITE) begin
              PSLVERR = 1'b1;
            end else begin
              PRDATA[STATUS_TX_BUSY_BIT]    = tx_busy_q;
              PRDATA[STATUS_TX_READY_BIT]   = !tx_busy_q;
              PRDATA[STATUS_RX_VALID_BIT]   = rx_valid_q;
              PRDATA[STATUS_RX_OVERRUN_BIT] = rx_overrun_q;
              PRDATA[STATUS_FRAME_ERR_BIT]  = frame_error_q;
            end
          end

          UART_CTRL_ADDR: begin
            if (!PWRITE) begin
              PRDATA[5:0] = ctrl_q;
            end
          end

          UART_BAUD_DIV_ADDR: begin
            if (PWRITE) begin
              if ((PSTRB[1:0] != 2'b00) && (merged_baud_div < 16'd2)) begin
                PSLVERR = 1'b1;
              end
            end else begin
              PRDATA[15:0] = baud_div_q;
            end
          end

          UART_IRQ_STATUS_ADDR: begin
            if (!PWRITE) begin
              PRDATA[2:0] = irq_status_q;
            end
          end

          UART_SCRATCH_ADDR: begin
            if (!PWRITE) begin
              PRDATA = scratch_q;
            end
          end

          default: begin
            PSLVERR = 1'b1;
          end
        endcase
      end
    end
  end

  assign apb_access = PSEL && PENABLE && PREADY;
  assign apb_commit = apb_access && !PSLVERR;

  assign data_write_start = apb_commit && PWRITE &&
                            (PADDR == UART_DATA_ADDR) && PSTRB[0];
  assign data_read_pop = apb_commit && !PWRITE &&
                         (PADDR == UART_DATA_ADDR) && rx_valid_q;
  assign status_read = apb_commit && !PWRITE &&
                       (PADDR == UART_STATUS_ADDR);
  assign ctrl_clear_errors = apb_commit && PWRITE &&
                             (PADDR == UART_CTRL_ADDR) &&
                             PSTRB[1] && PWDATA[CTRL_CLR_ERRORS_BIT];

  // APB-visible register and sticky-status state.
  always_ff @(posedge PCLK) begin
    if (!PRESETn) begin
      ctrl_q        <= '0;
      baud_div_q    <= RESET_BAUD_DIV[15:0];
      scratch_q     <= '0;
      rx_data_q     <= '0;
      rx_valid_q    <= 1'b0;
      rx_overrun_q  <= 1'b0;
      frame_error_q <= 1'b0;
      irq_status_q  <= '0;
    end else begin
      if (apb_commit && PWRITE && (PADDR == UART_CTRL_ADDR) && PSTRB[0]) begin
        ctrl_q <= PWDATA[5:0];
      end

      if (apb_commit && PWRITE && (PADDR == UART_BAUD_DIV_ADDR)) begin
        baud_div_q <= merged_baud_div;
      end

      if (apb_commit && PWRITE && (PADDR == UART_SCRATCH_ADDR)) begin
        if (BUG_MASK[0]) begin
          scratch_q <= PWDATA;
        end else begin
          for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
            if (PSTRB[byte_index]) begin
              scratch_q[byte_index*8 +: 8] <= PWDATA[byte_index*8 +: 8];
            end
          end
        end
      end

      if (data_read_pop) begin
        rx_valid_q <= 1'b0;
      end

      if (ctrl_clear_errors) begin
        rx_overrun_q  <= 1'b0;
        frame_error_q <= 1'b0;
      end

      // Intentional exercise: a STATUS read must not clear this sticky bit.
      if (BUG_MASK[2] && status_read) begin
        frame_error_q <= 1'b0;
      end

      if (rx_byte_event) begin
        if (!rx_valid_q || data_read_pop) begin
          rx_data_q  <= rx_event_data;
          rx_valid_q <= 1'b1;
        end else begin
          rx_overrun_q <= 1'b1;
          // Intentional exercise: correct hardware keeps the older byte.
          if (BUG_MASK[1]) begin
            rx_data_q <= rx_event_data;
          end
        end
      end

      if (rx_frame_error_event) begin
        frame_error_q <= 1'b1;
      end

      if (apb_commit && PWRITE && (PADDR == UART_IRQ_STATUS_ADDR) && PSTRB[0]) begin
        irq_status_q <= irq_status_q & ~PWDATA[2:0];
      end

      // Hardware set has priority over an APB W1C in the same cycle.
      if (rx_byte_event && (!rx_valid_q || data_read_pop)) begin
        irq_status_q[IRQ_RX_BIT] <= 1'b1;
      end
      if ((rx_byte_event && rx_valid_q && !data_read_pop) || rx_frame_error_event) begin
        irq_status_q[IRQ_ERR_BIT] <= 1'b1;
      end
      if (tx_done_event) begin
        irq_status_q[IRQ_TX_DONE_BIT] <= 1'b1;
      end
    end
  end

  // UART transmitter. The baud divisor is latched at the beginning of a frame.
  always_ff @(posedge PCLK) begin
    if (!PRESETn) begin
      tx_state_q       <= TX_IDLE;
      tx_shift_q       <= '0;
      tx_bit_index_q   <= '0;
      tx_count_q       <= '0;
      tx_div_latched_q <= RESET_BAUD_DIV[15:0];
      tx_busy_q        <= 1'b0;
      tx_q             <= 1'b1;
      tx_done_event    <= 1'b0;
    end else begin
      tx_done_event <= 1'b0;

      case (tx_state_q)
        TX_IDLE: begin
          tx_q      <= 1'b1;
          tx_busy_q <= 1'b0;
          if (data_write_start) begin
            tx_shift_q       <= PWDATA[7:0];
            tx_bit_index_q   <= '0;
            tx_div_latched_q <= baud_div_q;
            tx_count_q       <= baud_div_q - 16'd1;
            tx_state_q       <= TX_START;
            tx_busy_q        <= 1'b1;
            tx_q             <= 1'b0;
          end
        end

        TX_START: begin
          if (tx_count_q == 16'd0) begin
            tx_count_q     <= tx_div_latched_q - 16'd1;
            tx_state_q     <= TX_DATA;
            tx_bit_index_q <= 3'd0;
            tx_q           <= tx_shift_q[0];
          end else begin
            tx_count_q <= tx_count_q - 16'd1;
          end
        end

        TX_DATA: begin
          if (tx_count_q == 16'd0) begin
            tx_count_q <= tx_div_latched_q - 16'd1;
            if (tx_bit_index_q == 3'd7) begin
              tx_state_q <= TX_STOP;
              tx_q       <= 1'b1;
            end else begin
              tx_bit_index_q <= tx_bit_index_q + 3'd1;
              tx_q <= tx_shift_q[tx_bit_index_q + 3'd1];
            end
          end else begin
            tx_count_q <= tx_count_q - 16'd1;
          end
        end

        TX_STOP: begin
          if (tx_count_q == 16'd0) begin
            tx_state_q    <= TX_IDLE;
            tx_busy_q     <= 1'b0;
            tx_q          <= 1'b1;
            tx_done_event <= 1'b1;
          end else begin
            tx_count_q <= tx_count_q - 16'd1;
          end
        end

        default: begin
          tx_state_q <= TX_IDLE;
          tx_busy_q  <= 1'b0;
          tx_q       <= 1'b1;
        end
      endcase
    end
  end

  // UART receiver with mid-start-bit validation and center sampling.
  always_ff @(posedge PCLK) begin
    if (!PRESETn) begin
      rx_state_q             <= RX_IDLE;
      rx_shift_q             <= '0;
      rx_bit_index_q         <= '0;
      rx_count_q             <= '0;
      rx_div_latched_q       <= RESET_BAUD_DIV[15:0];
      rx_byte_event          <= 1'b0;
      rx_event_data          <= '0;
      rx_frame_error_event   <= 1'b0;
    end else begin
      rx_byte_event        <= 1'b0;
      rx_frame_error_event <= 1'b0;

      if (!ctrl_q[CTRL_RX_EN_BIT]) begin
        rx_state_q <= RX_IDLE;
      end else begin
        case (rx_state_q)
          RX_IDLE: begin
            if (!rx_sample) begin
              rx_div_latched_q <= baud_div_q;
              rx_count_q       <= (baud_div_q >> 1) - 16'd1;
              rx_state_q       <= RX_START;
            end
          end

          RX_START: begin
            if (rx_count_q == 16'd0) begin
              if (!rx_sample) begin
                rx_count_q     <= rx_div_latched_q - 16'd1;
                rx_bit_index_q <= 3'd0;
                rx_state_q     <= RX_DATA;
              end else begin
                rx_state_q <= RX_IDLE;
              end
            end else begin
              rx_count_q <= rx_count_q - 16'd1;
            end
          end

          RX_DATA: begin
            if (rx_count_q == 16'd0) begin
              rx_shift_q[rx_bit_index_q] <= rx_sample;
              rx_count_q <= rx_div_latched_q - 16'd1;
              if (rx_bit_index_q == 3'd7) begin
                rx_state_q <= RX_STOP;
              end else begin
                rx_bit_index_q <= rx_bit_index_q + 3'd1;
              end
            end else begin
              rx_count_q <= rx_count_q - 16'd1;
            end
          end

          RX_STOP: begin
            if (rx_count_q == 16'd0) begin
              rx_event_data        <= rx_shift_q;
              rx_byte_event        <= 1'b1;
              rx_frame_error_event <= !rx_sample;
              rx_state_q           <= RX_IDLE;
            end else begin
              rx_count_q <= rx_count_q - 16'd1;
            end
          end

          default: begin
            rx_state_q <= RX_IDLE;
          end
        endcase
      end
    end
  end

endmodule
