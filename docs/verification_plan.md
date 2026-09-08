# APB-UART UVM 验证计划

## 1. 项目目标

本项目验证一个通过 APB3/APB4 风格寄存器接口控制的全双工 UART。验证平台以 UVM 1.2 为基线，覆盖以下能力：

- APB 主设备对 UART 寄存器的读写、错误响应和字节写使能。
- UART 8N1 发送、接收、内部回环、帧错误和接收溢出。
- 寄存器复位值、访问属性、读写副作用和中断状态。
- 基于 UVM RAL 的前门访问和镜像预测。
- 面向接口、协议、数据和场景的功能覆盖率。
- APB 时序断言以及复位/输出基本断言。
- 定向测试、受约束随机测试和专门的调试练习。

项目只包含 RTL 与验证源代码、规格和使用文档，不包含仿真器脚本、Makefile、依赖安装或虚拟机环境配置。

## 2. DUT 功能边界

### 2.1 APB 接口

- 地址宽度：12 bit。
- 数据宽度：32 bit。
- 支持 `PSTRB[3:0]` 字节写使能。
- 零等待响应：合法传输的 access phase 中 `PREADY=1`。
- 非法地址、未对齐地址、只读寄存器写、禁用或忙状态下的 DATA 写返回 `PSLVERR=1`。
- APB 写在 `PSEL && PENABLE && PREADY && !PSLVERR` 时生效。
- APB 读数据在 access phase 有效。

### 2.2 UART 接口

- 固定格式：1 个起始位、8 个数据位、无校验、1 个停止位（8N1）。
- 数据低位先发送。
- `BAUD_DIV` 表示每个 UART bit 占用的 `PCLK` 周期数，最小合法值为 2。
- TX 和 RX 可独立使能。
- 单字节 RX holding register；未读取时收到新字节产生 overrun。
- 停止位为 0 时置位 sticky frame error。
- 支持内部数字回环：TX 输出同时送入 RX 采样器。

### 2.3 中断

- 成功保存 RX 字节时置位 sticky RX 中断状态。
- RX overrun 或 frame error 在 error 中断使能时产生中断条件。
- TX 完成置位 sticky `TX_DONE` 中断状态。
- `IRQ_STATUS` 使用写 1 清零（W1C）。
- 顶层 `irq` 是已使能且尚未清除的中断条件之 OR。

详细寄存器定义见 [register_spec.md](register_spec.md)。

## 3. 验证平台架构

```text
                         +-------------------------------+
 virtual sequence ----->| virtual sequencer             |
                         +---------------+---------------+
                                         |
                     +-------------------+-------------------+
                     |                                       |
              +------v-------+                        +------v-------+
              | APB agent    |                        | UART agent   |
              | sequencer    |                        | sequencer    |
              | driver       |                        | RX driver    |
              | monitor      |                        | TX monitor   |
              | coverage     |                        | coverage     |
              +------+-------+                        +------+-------+
                     | APB                                   | serial
                 +---v---------------------------------------v---+
                 |                 APB UART DUT                  |
                 +---+---------------------------------------+---+
                     |                                       |
          +----------v-----------+               +-----------v----------+
          | RAL predictor/model  |               | reference scoreboard |
          +----------------------+               +----------------------+
```

### 3.1 APB agent

- active 模式下产生 setup/access phase，并等待 `PREADY`。
- 记录读数据、`PSLVERR` 和等待周期数到 response item。
- monitor 独立重建总线传输并广播给 scoreboard、RAL predictor 和 coverage subscriber。
- 支持单次读写序列、空闲周期、字节写使能和非法访问激励。

### 3.2 UART agent

- RX driver 在 `uart_rx` 上产生 8N1 串行帧，可注入错误停止位。
- TX monitor 对 `uart_tx` 解码，输出收到的数据及帧错误信息。
- driver 的完成事务同时送入 scoreboard，作为 DUT RX 路径的输入参考。
- 共享配置对象中的 `bit_cycles` 由 APB BAUD_DIV 写事务动态更新。

### 3.3 UVM RAL

- 建模 DATA、STATUS、CTRL、BAUD_DIV、IRQ_STATUS 和 SCRATCH。
- APB adapter 完成 `uvm_reg_bus_op` 与 APB transaction 的转换。
- predictor 根据 APB monitor 的实际传输更新镜像。
- volatile/status 字段主要由前门读检查，避免依赖静态镜像判断动态硬件状态。

### 3.4 Scoreboard/reference model

- APB DATA 写形成期望 TX 字节队列；UART TX monitor 每解码一帧即按序比较。
- UART RX driver 完成一帧后更新单字节 RX 参考模型；DATA 读检查返回值和 pop 副作用。
- 建模 CTRL、BAUD_DIV、SCRATCH、sticky error 和 IRQ_STATUS。
- 对动态 TX busy/ready 位采取掩码比较，串行数据端到端检查负责 TX 主功能判定。
- `check_phase` 检查是否仍有未被 DUT 发出的期望 TX 数据。

## 4. 检查策略

| 检查对象 | 激励端 | 观察端 | 判定方式 |
|---|---|---|---|
| APB 寄存器 | APB driver/RAL | APB monitor | 返回数据、错误响应、寄存器参考模型 |
| UART TX | DATA write | TX monitor | 字节队列逐项比较 |
| UART RX | RX serial driver | DATA read/status | holding register 模型逐项比较 |
| frame error | bad stop frame | STATUS/IRQ | sticky 状态和清除行为 |
| overrun | 连续两个未读 RX frame | STATUS/DATA | sticky 状态及首字节保持策略 |
| loopback | DATA write | TX monitor + DATA read | TX 与内部 RX 双路径比较 |
| interrupt | RX/error/TX done | APB IRQ_STATUS + `irq` assertion | 状态、使能、W1C |
| reset | reset interface | APB/UART/irq | 默认值、TX idle、无未知态 |

## 5. 功能覆盖率计划

### 5.1 APB 覆盖

- 读/写类型。
- 每个寄存器地址和非法地址。
- `PSTRB`：全写、单字节、其他部分写。
- 正常/错误响应。
- 0、1、2~3、4+ 空闲周期及等待周期桶。
- 地址 × 操作类型 × 错误响应交叉。

### 5.2 UART 覆盖

- 数据：`00`、`FF`、walking-one、walking-zero、普通数据。
- 正常停止位/错误停止位。
- bit 周期：最小值、小值、中值、大值。
- 数据类别 × 帧错误交叉。

### 5.3 场景覆盖

- TX-only、RX-only、全双工、loopback。
- RX valid 为空/占用时的新帧到达。
- frame error、overrun 的产生与清除。
- TX done、RX、error 中断的置位和 W1C。
- 复位发生于空闲与活动期间。

## 6. 测试清单

| 测试类 | 主要目标 | 预期 |
|---|---|---|
| `uart_apb_smoke_test` | 基础 TX、RX、状态和 DATA 访问 | 通过 |
| `uart_apb_ral_test` | RAL reset/read-write/mirror 基础路径 | 通过 |
| `uart_apb_tx_test` | 边界数据和连续 TX | 通过 |
| `uart_apb_rx_test` | 边界数据和连续 RX/read | 通过 |
| `uart_apb_loopback_test` | 内部回环端到端 | 通过 |
| `uart_apb_full_duplex_test` | TX 与外部 RX 并行活动 | 通过 |
| `uart_apb_error_response_test` | 非法地址、未对齐、RO 写、busy 写 | 通过 |
| `uart_apb_baud_test` | 多个合法 BAUD_DIV 下的 TX/RX | 通过 |
| `uart_apb_irq_test` | RX/error/TX-done 中断和 W1C | 通过 |
| `uart_apb_random_test` | 受约束随机合法 TX/RX、全写寄存器和状态访问 | 通过 |
| `uart_apb_reset_test` | 活动中复位和复位后恢复 | 通过 |
| `uart_apb_debug_scratch_test` | 部分字节写语义 | 默认练习缺陷下失败 |
| `uart_apb_debug_overrun_test` | overrun 后首字节保持 | 默认练习缺陷下失败 |
| `uart_apb_debug_frame_error_test` | frame error sticky 语义 | 默认练习缺陷下失败 |

## 7. 收敛标准

- 所有非 debug 测试无 UVM error/fatal。
- 修复练习缺陷后，所有 debug 测试通过。
- APB assertion 无失败。
- 计划内功能覆盖点达到 100%，不可达点经审查后排除。
- 代码覆盖目标建议：statement/branch/toggle ≥ 95%，FSM state/transition 100%。
- scoreboard 在结束时无遗留期望 TX transaction。

## 8. 有意保留的调试内容

DUT 默认启用三项彼此独立的练习缺陷：SCRATCH 部分写、RX overrun 数据保持、frame error sticky 保持。它们不影响基础 smoke 的主要路径，并各有一个定向测试稳定复现。现象、定位建议和验收条件见 [debug_exercises.md](debug_exercises.md)。

这些缺陷通过 DUT 参数 `BUG_MASK[2:0]` 控制，便于建立“带缺陷”和“修复后”两个回归基线。默认值为 `3'b111`；参数设为 `3'b000` 可作为正确行为参考。

## 9. 需求可追踪矩阵

| ID | 验证需求 | 主要 checker | 覆盖点 | 主要测试 |
|---|---|---|---|---|
| APB-01 | setup phase 后进入 access phase | `apb_if` SVA | direction/address | 全部 APB 测试 |
| APB-02 | wait 期间控制信号稳定 | `apb_if` SVA + monitor | wait bucket | agent 复用能力；本 DUT 零等待 |
| APB-03 | 合法读写零等待完成 | response + monitor | address × direction × no-error | smoke、RAL |
| APB-04 | 非法/未对齐地址报错 | sequence response | address × error | error-response |
| APB-05 | RO 写和非法 DATA 写报错 | sequence response | operation × error | error-response |
| APB-06 | byte strobe 只更新选中 byte | scoreboard | 所有 strobe 类型 | debug-scratch |
| REG-01 | CTRL 访问和复位值 | scoreboard + RAL | CTRL read/write | RAL、reset |
| REG-02 | BAUD_DIV 访问、复位和非法值 | scoreboard + RAL | divisor bucket × error | RAL、baud、error-response |
| REG-03 | DATA 读 pop 与空读 | scoreboard | RX valid 状态 | smoke、RX、random |
| REG-04 | STATUS 动态/粘滞位 | scoreboard | status/error event | smoke、debug tests |
| REG-05 | IRQ_STATUS 硬件置位/W1C | scoreboard + sequence | IRQ source | IRQ |
| TX-01 | 8N1、LSB-first、正确数据 | TX monitor + scoreboard | data class | TX、smoke |
| TX-02 | divisor 控制 bit 宽度 | TX monitor | divisor bucket | baud |
| TX-03 | busy 时拒绝第二次 DATA 写 | APB response | busy × DATA write × error | error-response |
| RX-01 | 起始位确认和 8-bit 数据采样 | RX model + DATA compare | data class | RX、smoke |
| RX-02 | 正确停止位正常接收 | DATA/status compare | frame-error=0 | RX、baud |
| RX-03 | 错误停止位置 sticky frame error | scoreboard | frame-error=1 | debug-frame-error、IRQ |
| RX-04 | holding 满时 overrun 且保留旧值 | scoreboard | occupied × new frame | debug-overrun |
| MODE-01 | TX/RX 同时工作互不干扰 | 双路径 scoreboard | full-duplex mode | full-duplex |
| MODE-02 | 内部 loopback 端到端 | TX + delayed loopback reference | loopback × data | loopback |
| IRQ-01 | 各中断源受 CTRL enable 控制 | pin observation + register check | source × enable | IRQ |
| RST-01 | 复位值、TX idle、IRQ known | RAL/readback + SVA | reset activity | reset、RAL |
| RST-02 | 活动中复位清空未完成参考事务 | reset-aware monitor/scoreboard | active reset | reset |

## 10. 复位与并发处理策略

- 顶层产生首次同步复位，test 可通过 `reset_if.apply_reset()` 再次施加复位。
- APB driver 遇到传输中复位会返回 `aborted` response，并将总线拉回 idle。
- UART RX driver 与 TX monitor 在等待 bit 周期时并行监听复位下降沿；复位会终止并丢弃不完整帧，避免形成伪 transaction。
- scoreboard 在每个复位下降沿清空寄存器参考状态、期望 TX 队列和待提交 loopback 数据。
- full-duplex virtual sequence 在两个独立 sequencer 上并发启动 APB TX 与 UART RX；共享 APB sequencer 的轮询请求由 UVM arbitration 串行化。
- loopback RX 相对 TX monitor 的 stop-bit 中点有固定流水延迟；scoreboard 使用延迟队列建模，并在已知的短暂观测窗口屏蔽 `RX_VALID` 比较，数据本身仍严格比较。

## 11. 失败分类与定位信息

建议按以下顺序归类首个失败，避免后续连锁错误干扰判断：

1. SVA/APB protocol 失败：先检查 driver clocking skew、PSEL/PENABLE 和 reset 时序。
2. APB response 与 sequence 期望不符：检查地址合法性、访问属性、busy/enable 前置条件。
3. 寄存器 scoreboard mismatch：检查 byte strobe、sticky/W1C 或读副作用。
4. UART TX byte mismatch：从 DATA access 时间开始，对齐 start/data/stop bit 和 divisor。
5. UART RX DATA mismatch：检查 RX driver bit 周期、RX FSM 中点采样和 holding/overrun 状态。
6. `check_phase` 遗留 TX：说明已接受 DATA 写但未观察到完整 TX 帧，也可能是测试过早结束。

每个 transaction 都继承 UVM 的 `sprint()`/recording 字段；建议在虚拟机仿真环境中按需提高相关 component verbosity，并保存 APB、UART、TX/RX FSM、divisor、holding register 和 IRQ 状态波形。

## 12. 当前范围之外的可扩展项

以下能力未纳入当前 DUT 规格，但 agent/env 的分层结构允许后续扩展：

- 奇偶校验、5/6/7-bit 数据、1.5/2 stop bit。
- TX/RX FIFO、FIFO watermark 和 DMA handshake。
- APB wait-state/error 注入 slave，或复用 APB master agent 验证其他外设。
- 独立 UART passive RX monitor，以验证外部激励线而非仅使用 driver completed transaction。
- UVM register bit-bash、access、reset 等标准 sequence 的白名单封装。
- 多 UART instance、地址 remap、不同 PCLK 与 UART oversampling clock domain。
- formal property set、CDC/RDC、低功耗和门级回归。
