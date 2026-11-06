# 九种并口 MRAM 数据类型

本版本基于 `31100b0`，分支 `fix/data-patterns-nine`。
配置字节 3（din_sel）取值 1–9，x16 数据定义如下：

| din_sel | 数据类型 | 从测试起始地址开始的数据 |
| --- | --- | --- |
| 1 | 全 0 | 0000、0000、0000… |
| 2 | 全 F | FFFF、FFFF、FFFF… |
| 3 | 5555/AAAA 交替 | 5555、AAAA、5555… |
| 4 | AAAA/5555 交替 | AAAA、5555、AAAA… |
| 5 | 0000/FFFF 交替 | 0000、FFFF、0000… |
| 6 | FFFF/0000 交替 | FFFF、0000、FFFF… |
| 7 | 递增数 | 0000、0001、0002…FFFF、0000… |
| 8 | 递减数 | FFFF、FFFE、FFFD…0000、FFFF… |
| 9 | 随机数 | 沿用 TRNG 种子 + xorshift32，取完整低 16 位 |

交替按相邻地址变化；相位和递增/递减起点以本次测试的起始地址为基准，
不取决于该地址的奇偶或数值。每轮重新从首值开始，读阶段恢复同轮写入的序列。
x8 并口沿用上述编号，取对应数据的低字节；随机模式仍使用原有字节复制规则。

所有类型均沿用原有单遍流程：只写每轮写 N 个地址，只读每轮读验 N 个地址，
写读每轮先写 N 个地址，再读验 N 个地址。模式 1/2 不自动切换背景或执行第二遍。
每轮只返回一次汇总；详细错误继续使用 4096 条 FIFO 和原 25 字节帧。

读写周期、地址/控制信号、IOB、SPI 协议与基线一致。
Read1 实际锁存仍为 +40 ns，Read2 仍为 +45 ns；未合入 0b68c2e 的 Read1 45 ns 修改。

## 上位机与本机更新

SPI 配置及报告格式不变；现有上位机发送编号 1–9 即可使用。
若界面仍显示旧类型名称，须按上表更新下拉项和日志名称，避免编号含义混淆。
本仓库只有已发布的上位机程序，没有其源代码。

```bash
cd /e/workspace/xilinx_workspace/MRAM_EVB
git fetch origin fix/data-patterns-nine
git checkout -B fix/data-patterns-nine FETCH_HEAD
git log -1 --oneline
```

关闭 Vivado 后更新源码，打开同一 `.xpr`，Reset `synth_2`，重新综合、实现、生成 bit。
云端数字仿真不代表 Vivado 的 setup/hold 已通过；需要用新实现报告确认。

## 回归

`bash tests/run_random_pattern.sh` 包含 176 个用例：原长度边界及随机重放，
以及新增 96 组固定类型短区间组合（8 类型 × 3 写模式 × 2 读模式 × 长度 1/5）。
新增组合使用奇数非零起始地址和两轮测试，检查起始值、相邻地址序列、写入/采样数量、
读期望值和每轮唯一汇总。另保留长度 577/1025 的全部固定类型测试。
`bash tests/run_top_timing.sh` 检查独立引脚时序、边界算术和只写/只读/写读上报。
`bash tests/run_spi_detail.sh` 检查密集错误、缓存溢出和异步上报。
