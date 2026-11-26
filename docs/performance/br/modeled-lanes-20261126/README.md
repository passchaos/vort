# Compact modeled DP and adjacent lanes，2026-11-26

**结论：拒绝本组合候选，生产代码未合入。** 十二语料两轮公共 q8 pilot
给出吞吐几何平均 **1.00989168x**，NCI **1.05102553x**，Mozilla
**0.90980929x**。未达到既定 1.03x / 1.20x / 0.98x 门槛，因此停止，
不追加样本至通过，不把正确性验证或潜在内存收益当成性能合入许可。

## 当前源码与候选范围

基线公共 Brotli/lz77 代码对应 main `f60685e5`，自已接受的 `7b575072`
没有变化；复用 V7 实际 ELF，原构建回执和原 stamp 保留，不改写成新构建。
候选从 f606 的 Git source archive 创建，最终 src manifest 含 2201 项。
双方使用同一公共 API probe、Zig 0.16.0 ReleaseFast、
`x86_64-linux-gnu`、`skylake+pku+sgx`、i7-10700K 和 CPU 2。

候选采用紧凑 u32 单模型成本与回溯状态，将两个模型的成本/回溯字段放在
相邻 lane，并在一个循环里计算两个模型的长度选择。价格表和输入保持
不可变；候选顺序、实际距离价格、预算消耗、最长长度 tie 和严格成本更新
均保留。旧双模型实现和普通全宽解析器保留为独立 oracle。
这是一组一起测量的结构改动，不能将结果归因于 SIMD、布局或某一组件。

## 真实公共操作筛查

输入为原始 Silesia 十二份 **65536-byte 前缀**，不重复、填充或归一化。
公共 q8/generic/explicit window16，普通 allocating encode、length mix
和 free 在连续计时区间内；每个 child 一次 untimed encode/free warmup，
一次 timed encode。初始完整 wire 保存、SHA 和参考解码在计时外。

两轮依次 AB / BA，每行 2 pairs，共 **24 pairs / 48 timed calls**。
统计保留两次 log 时间比并取均值，再给十二行相同权重的几何平均；
没有独立最快轮选择、慢样本删除或重试。本结果是开发机 pilot，未运行
完整六轮、95% CI、公共等级 controls 或资源/峰值验收。

| 输入 | Candidate / baseline 吞吐 |
| --- | ---: |
| dickens | 0.99537677x |
| mozilla | 0.90980929x |
| mr | 1.01375852x |
| nci | 1.05102553x |
| ooffice | 1.03485152x |
| osdb | 1.00064364x |
| reymont | 1.01451506x |
| samba | 1.01465651x |
| sao | 1.02398109x |
| webster | 1.02355617x |
| x-ray | 1.00518861x |
| xml | 1.03854583x |

所有初始完整 wire 跨版本逐字节相等，并由固定的 libbrotli decoder/common
1.2.0 解码至原始输入。库文件 SHA、实际 decoder version 和 maps 保留。
timed 输出只检查长度/mix；没有声称每个 timed wire 都重新解码。

## 正确性与诊断边界

实际 native ReleaseSafe 与 WASI 各通过 12 项 runner tests，包含普通
全宽解析器的 token/stats 对照、0/65536/65537 边界、非单调距离价格、
预算、字典和分配失败清理。新增的高成本字典用例使一个 lane 的成本跨越
u32 符号位，另一个 lane 保持 literal，并对照单模型及双模型完整 tokens。
单模型的 allocation-failure sweep 也已执行。

当前基线 profile 使用十个公共进程，每个 1 warmup + 3 encodes，录得
**3502 samples**。全部周期中，含内联建模 DP 的外层函数为 **39.75%**，
初始 optimal parser **19.83%**，独立 matchLength **4.38%**；分母还包含
provenance/ELF SHA、I/O 和未解析内核样本。这些不是纯编码阶段占比。
readelf 解出的正行号覆盖 **47.5349%** 全周期，compiler line zero 留作
未归因。GNU addr2line 路径未完成并被停止，不作为 codec/test 失败。

完整性能或内存领先尚未证明。下一步优先关闭 Deflate 显式可复用工作区
的能力缺口；继续性能工作时应移除重复规划和输出 materialization，
保持质量和完整操作门槛。

## 离线核验

在该目录执行 `PYTHONDONTWRITEBYTECODE=1 python3 verify.py`。
归档与离线重放成功只表示证据完整，`decision=rejected` 仍保持不变。
验证入口不启动 codec、compiler、SO 或 benchmark，不读取原临时目录。
