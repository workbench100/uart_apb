# APB UART UVM 验证项目

这是一个从零构建的 UVM 1.2 教学/练习项目：DUT 是带 32-bit APB 寄存器接口的 8N1 UART，验证环境包含 APB master agent、UART RX driver/TX monitor、UVM RAL、reference scoreboard、功能覆盖率、SVA 和一组虚拟序列/测试。

本目录只保存源代码与文档。项目不提供、也不修改宿主机的仿真器配置、依赖、Makefile 或运行脚本；请在你的虚拟机中按所用仿真器完成编译和运行配置。

## 文档入口

- [完整验证计划](docs/verification_plan.md)
- [寄存器规格](docs/register_spec.md)
- [故意保留的调试练习](docs/debug_exercises.md)

## 目录结构

```text
uart_apb/
├── rtl/
│   ├── uart_apb_regs_pkg.sv       # 地址、字段位定义
│   └── apb_uart.sv                # APB UART DUT
├── tb/
│   ├── interfaces/
│   │   ├── reset_if.sv
│   │   ├── apb_if.sv              # APB clocking block + SVA
│   │   └── uart_if.sv             # UART/IRQ interface + SVA
│   ├── apb_agent/                  # APB item/config/driver/monitor/coverage/sequences
│   ├── uart_agent/                 # UART item/RX driver/TX monitor/coverage/sequences
│   ├── env/                        # RAL、adapter、predictor、scoreboard、virtual sequences
│   ├── tests/                      # UVM test classes
│   ├── assertions/                 # DUT 接口级补充断言
│   └── top/tb_top.sv               # 时钟、复位、DUT 和 UVM 顶层
└── docs/
```

## 建议编译顺序

请让仿真器启用 SystemVerilog 和 UVM 1.2，并把各 agent/env/test 目录加入 include search path。独立 compilation unit 的顺序如下：

1. 仿真器提供的 UVM package。
2. `rtl/uart_apb_regs_pkg.sv`
3. `tb/interfaces/reset_if.sv`
4. `tb/interfaces/apb_if.sv`
5. `tb/interfaces/uart_if.sv`
6. `tb/apb_agent/apb_agent_pkg.sv`
7. `tb/uart_agent/uart_agent_pkg.sv`
8. `tb/env/uart_apb_env_pkg.sv`
9. `tb/tests/uart_apb_test_pkg.sv`
10. `rtl/apb_uart.sv`
11. `tb/assertions/uart_apb_protocol_checks.sv`
12. `tb/top/tb_top.sv`

顶层模块为 `tb_top`。测试名通过仿真器支持的 UVM test-name 机制选择；代码中的 `run_test()` 未硬编码测试名。

## 测试类

基础功能测试：

- `uart_apb_smoke_test`
- `uart_apb_ral_test`
- `uart_apb_tx_test`
- `uart_apb_rx_test`
- `uart_apb_loopback_test`
- `uart_apb_full_duplex_test`
- `uart_apb_error_response_test`
- `uart_apb_baud_test`
- `uart_apb_irq_test`
- `uart_apb_reset_test`
- `uart_apb_random_test`

调试练习测试：

- `uart_apb_debug_scratch_test`
- `uart_apb_debug_overrun_test`
- `uart_apb_debug_frame_error_test`

## BUG_MASK 与预期结果

`tb_top.DUT_BUG_MASK` 默认是 `3'b111`，分别启用三个有意保留的局部缺陷。默认模式下，三个对应的 debug test 应报告 mismatch；基础 smoke 和常规收发测试的设计目标是通过。

将顶层参数覆盖为 `3'b000` 后，DUT 走规格定义的正确分支，全部 debug test 也应通过。推荐先跑 smoke，再逐个运行 debug test 做波形定位。不要通过关闭 scoreboard 或降低 UVM error 严重级别来“修复”练习。

## 关键设计约定

- APB 是零等待从设备，但 agent 本身支持等待状态，便于后续复用。
- UART divisor 直接表示每 bit 的 PCLK 数，最小为 2。
- UART monitor 和 RX driver 共享一个可动态更新的 divisor 配置对象。
- reference scoreboard 永远遵循文档中的正确规格，不跟随 `BUG_MASK` 改变期望值。
- 复位为低有效同步复位；reset interface 可供活动中复位测试调用。
- DATA/STATUS 属于动态和带副作用寄存器，RAL 镜像仅作辅助，最终判断以 monitor + scoreboard 为准。
