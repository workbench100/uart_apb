# 调试练习说明

DUT 参数 `BUG_MASK` 默认是 `3'b111`，故意保留三个局部缺陷。参考模型始终按寄存器规格中的正确行为工作，定向 debug test 因而会给出可重复的 mismatch。基础 smoke、正常 TX/RX、非法访问和大多数 RAL 检查不依赖这些角落行为。

## Exercise 1：SCRATCH 部分写

- 控制位：`BUG_MASK[0]`
- 复现测试：`uart_apb_debug_scratch_test`
- 激励：测试先全写 `32'h1122_3344`，再以更新值 `32'hDDEE_AABB` 遍历全部 16 种 `PSTRB`。
- 示例：当 `PSTRB=4'b0010` 时，正确结果为 `32'h1122_AA44`。
- 典型现象：未选中的 byte 也发生变化。
- 建议观察：APB monitor 中的 `strb`、DUT SCRATCH 写路径、scoreboard 的 byte merge 结果。
- 修复验收：所有 16 种 `PSTRB` 组合均保持未选中字节。

## Exercise 2：RX overrun 数据保持

- 控制位：`BUG_MASK[1]`
- 复现测试：`uart_apb_debug_overrun_test`
- 激励：RX 连续发送两个不同字节，中间不读取 DATA。
- 正确结果：`RX_OVERRUN=1`，DATA 仍返回第一个字节。
- 典型现象：状态位正确，但 DATA 返回第二个字节。
- 建议观察：`rx_byte_event`、`rx_valid`、`rx_data` 在第二个停止位采样时的关系。
- 修复验收：holding register 满时只置 overrun 并丢弃新字节。

## Exercise 3：frame error sticky 属性

- 控制位：`BUG_MASK[2]`
- 复现测试：`uart_apb_debug_frame_error_test`
- 激励：发送错误停止位帧，连续读取 STATUS 两次。
- 正确结果：两次读取的 `FRAME_ERR` 都为 1；仅 `CTRL.CLR_ERRORS` 可清除。
- 典型现象：第一次 STATUS 读取后错误位消失。
- 建议观察：STATUS read access 与 `frame_error` 寄存器更新条件。
- 修复验收：任意数量 STATUS 读均无副作用，W1P clear 能正确清除。

## 推荐调试流程

1. 单独运行相应 debug test，先从 scoreboard 的首个 mismatch 确认规格预期。
2. 同时观察 APB access transaction、UART 帧边界和 DUT 状态寄存器。
3. 将对应 `BUG_MASK` bit 临时设为 0，确认失败消失，排除 testbench 问题。
4. 在 RTL 中修正行为，而不是永久绕过 scoreboard 检查。
5. 重新运行该定向测试，再运行 smoke、RAL、random 回归确认无回归。
