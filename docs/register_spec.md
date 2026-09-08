# APB UART 寄存器规格

所有寄存器为 32 bit，地址按字对齐。复位为低有效同步复位 `PRESETn`。未定义地址或未对齐访问返回 `PSLVERR`。

## 寄存器总表

| 偏移 | 名称 | 属性 | 复位值 | 说明 |
|---:|---|---|---:|---|
| `0x00` | DATA | RW/side effect | `0x00000000` | 写入启动 TX；读取 RX holding register 并 pop |
| `0x04` | STATUS | RO | `0x00000002` | 动态状态和 sticky error |
| `0x08` | CTRL | RW | `0x00000000` | 使能、回环、中断使能及错误清除脉冲 |
| `0x0C` | BAUD_DIV | RW | `0x00000010` | 每个 UART bit 的 PCLK 周期数 |
| `0x10` | IRQ_STATUS | RW1C | `0x00000000` | sticky 中断状态 |
| `0x14` | SCRATCH | RW | `0x00000000` | 软件可读写测试寄存器 |

## DATA (`0x00`)

| 位 | 名称 | 属性 | 说明 |
|---|---|---|---|
| `[7:0]` | DATA | RW | 写：待发送字节；读：最早尚未读取的 RX 字节 |
| `[31:8]` | RESERVED | R0 | 读 0，写忽略 |

- DATA 写需要 `PSTRB[0]=1`、`CTRL.TX_EN=1` 且 TX idle，否则 `PSLVERR=1` 且写入不生效。
- DATA 读始终合法；`RX_VALID=0` 时返回 0。有效读取会清除 `RX_VALID`。
- RX holding register 已满时收到第二帧：保持原有首字节，丢弃新字节并置位 `RX_OVERRUN`。

## STATUS (`0x04`)

| 位 | 名称 | 属性 | 说明 |
|---|---|---|---|
| `0` | TX_BUSY | RO | TX 正在发送 |
| `1` | TX_READY | RO | TX 数据通道空闲；DATA 写仍要求 `TX_EN=1` |
| `2` | RX_VALID | RO | RX holding register 中有有效数据 |
| `3` | RX_OVERRUN | RO/sticky | 未读取旧数据时又收到新帧 |
| `4` | FRAME_ERR | RO/sticky | 最近至少一帧的停止位错误，尚未清除 |
| `[31:5]` | RESERVED | R0 | 读 0 |

读取 STATUS 不产生副作用。写 STATUS 返回 `PSLVERR`。

## CTRL (`0x08`)

| 位 | 名称 | 属性 | 说明 |
|---|---|---|---|
| `0` | TX_EN | RW | TX 使能 |
| `1` | RX_EN | RW | RX 使能 |
| `2` | RX_IRQ_EN | RW | RX valid 中断使能 |
| `3` | ERR_IRQ_EN | RW | overrun/frame error 中断使能 |
| `4` | TX_IRQ_EN | RW | TX done 中断使能 |
| `5` | LOOPBACK | RW | 1：RX 采样内部 TX；0：采样 `uart_rx` |
| `[7:6]` | RESERVED | R0 | 写忽略 |
| `8` | CLR_ERRORS | WO/pulse | 写 1 清除 STATUS 中的 sticky error |
| `[31:9]` | RESERVED | R0 | 写忽略 |

`PSTRB[0]` 控制 `[7:0]`，`PSTRB[1]` 控制 bit 8。`CLR_ERRORS` 不被保存。

## BAUD_DIV (`0x0C`)

| 位 | 名称 | 属性 | 说明 |
|---|---|---|---|
| `[15:0]` | DIVISOR | RW | 每个 UART bit 的 PCLK 周期数，合法范围 2~65535 |
| `[31:16]` | RESERVED | R0 | 读 0，写忽略 |

只在 `PSTRB[0]` 或 `PSTRB[1]` 置位时更新对应 byte。组合后的值小于 2 时返回 `PSLVERR`，原值保持。

## IRQ_STATUS (`0x10`)

| 位 | 名称 | 属性 | 说明 |
|---|---|---|---|
| `0` | RX_IRQ | RW1C | 收到并保存一个字节时置位 |
| `1` | ERR_IRQ | RW1C | overrun 或 frame error 时置位 |
| `2` | TX_DONE_IRQ | RW1C | 完成一个 TX 帧时置位 |
| `[31:3]` | RESERVED | R0 | 读 0，写忽略 |

硬件置位与同周期软件清零冲突时，硬件置位优先。

## SCRATCH (`0x14`)

普通 32-bit RW 寄存器。每个 byte 仅在对应 `PSTRB` 置位时更新，用于验证 APB byte strobe。

## IRQ 输出关系

```text
irq = (CTRL.RX_IRQ_EN  && IRQ_STATUS.RX_IRQ)
   || (CTRL.ERR_IRQ_EN && IRQ_STATUS.ERR_IRQ)
   || (CTRL.TX_IRQ_EN  && IRQ_STATUS.TX_DONE_IRQ)
```
