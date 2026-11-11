# 最新已验证源码的解码性能刷新，2026-11-11

本次完整测量固定在已验证提交
`ea193be259579ceda476c9278dd726fbfaec7e51`。Vort 的 cold 解码吞吐几何均值
分别达到 libdeflate 1.26 的 **68.77%**、libzstd 1.6.0 的 **76.56%**、
libbrotli 1.2.0 的 **80.86%**。这些值来自本次全部原始配对样本。
本轮刷新测量与证据，没有合入 codec 加速改动。

测量启动时，主工作树中 DirectChunk 的独立修复仍未完成验证；该改动没有
纳入这个性能 epoch。编译、测量和源码校验均使用独立 detached worktree，
完整证据见[归档说明](modern-decode-refresh-20261111/README.md)。

## Cold：每个 codec 的全部 72 行

表中吞吐比是 **Vort / 参考库**；耗时比是 **Vort / 参考库**，高于 1 表示
Vort 用时更长。每一行使用十二份 Silesia 文件、三种尺寸和两档 producer
level/quality，共 72 个固定条件；每个条件的六对测量样本全部参与计算。

| Codec / 参考版本 | Vort 相对参考吞吐 | 95% 固定行采样 CI | Vort 相对参考耗时 |
| --- | ---: | ---: | ---: |
| Deflate / libdeflate 1.26 | **68.77%** | 68.67%–68.88% | **1.4541×** |
| Zstd / libzstd 1.6.0 | **76.56%** | 76.30%–76.83% | **1.3062×** |
| Brotli / libbrotli 1.2.0 | **80.86%** | 80.72%–80.99% | **1.2368×** |

下面按输入尺寸展开，仍然报告 Vort / 参考库的配对耗时几何均值。
每个尺寸包含 24 行；全部 72 行的汇总给每个条件相同权重。

| Codec | 64 KiB | 1 MiB | 完整文件 |
| --- | ---: | ---: | ---: |
| Deflate cold | 1.5082× | 1.4210× | 1.4347× |
| Zstd cold | 1.2922× | 1.3262× | 1.3004× |
| Brotli cold | 1.2691× | 1.1605× | 1.2846× |

这里的 cold 表示每次调用的上下文生命周期。调用方输入、wire 和输出缓冲
提前分配；进程启动、文件读取、动态库加载和完整输出校验均在计时之外。
参考 Deflate 的 allocate/decompress/free 每次都在计时内；Zstd 使用
`ZSTD_decompress`，Brotli 使用包含状态初始化、内部工作区和清理的
`BrotliDecoderDecompress`。Vort 调用对应的公开 caller-buffer one-shot API。

## Prepared 生命周期

Zstd 的 `NativeFrameDecoder` 和 `ZSTD_DCtx` 都在计时外创建并 prime，随后
复用。这 72 行的吞吐比为 **77.73%**，95% CI 为 **77.58%–77.89%**，
配对耗时比为 **1.2864×**。

Deflate 额外的 72 行仅复用参考库 decompressor，Vort 仍调用相同的公开
`decodeRawDeflate`。它们标为 `reference-only-prepared`：吞吐比 **68.83%**，
95% CI **68.70%–68.96%**，耗时比 **1.4529×**。该标签保留双方上下文
复用能力的实际差异。Brotli 在此 probe 中没有支持的匹配 reset/reuse API，
因此没有 prepared 行。

| 生命周期 | 64 KiB 耗时比 | 1 MiB 耗时比 | 完整文件耗时比 |
| --- | ---: | ---: | ---: |
| Zstd matched prepared | 1.2076× | 1.3404× | 1.3153× |
| Deflate reference-only prepared | 1.5118× | 1.4221× | 1.4266× |

## 保留弱行，供下一轮 profiling

| Codec | 条件 | Vort 相对参考耗时 | Vort 相对参考吞吐 |
| --- | --- | ---: | ---: |
| Deflate | reymont，64 KiB，L6 | **1.6625×** | 60.15% |
| Deflate | nci，64 KiB，L6 | 1.6341× | 61.20% |
| Zstd | sao，完整文件，L3 | **1.5296×** | 65.38% |
| Zstd | sao，1 MiB，L3 | 1.5243× | 65.60% |
| Brotli | mozilla，完整文件，q11 | **2.0556×** | 48.65% |
| Brotli | samba，完整文件，q6 | 1.7613× | 56.78% |
| Brotli | x-ray，64 KiB，q6 | 1.6927× | 59.08% |

下一轮优先 profiling Deflate 的 64 KiB 弱行，以及 Brotli 的 mozilla 完整
文件 q11 cliff，再据热点决定结构调整或 kernel 优化。

## 协议、主机与证据范围

- 全部 **360 行**正常完成：216 cold、72 Zstd prepared、72 Deflate
  reference-only prepared。保留 **2,160 个 measured pairs** 和 **720 个
  warmup pairs**；每行六对测量、两对预热，AB/BA 顺序平衡，没有选取最小值。
- 十二份 Silesia 文件；64 KiB、1 MiB、完整文件；Deflate L6/L9、Zstd L3/L19、
  Brotli q6/q11。复用之前冻结的 **216 条 wire、36 份 plain**，逐份核对
  SHA、长度和 producer 设置，没有重新压缩。
- 每次解码检查返回长度；每个批次在计时后检查完整输出、输入/wire 不变和
  64-byte guards。Deflate 两边暴露精确输入消费量并核对。选中的 Zstd/Brotli
  one-shot API 不暴露该计数，归档明确保留消费量覆盖范围。
- Intel i7-10700K，逻辑 CPU **15**；Zig **0.16.0 ReleaseFast**，
  `x86_64-linux-gnu`，`skylake+pku+sgx`。参考库使用记录的 GCC 11.4 Release
  / Skylake 编译选项，精确路径、版本、SO SHA 和实际映射集合逐行校验。
- `intel_pstate` / `powersave`，turbo 开启。360 行边界观察中均未出现编译
  进程；load1 范围 **0.3125–1.3081**。272 个整个 child 生命周期内出现
  潜在背景 tick 活动，主要来自 traex；这是进程 tick 和 last-seen CPU
  标签观察，不能定位到具体 timed batch 的重叠。
- CI 采用固定行、按 AB/BA 分层的 paired log-ratio bootstrap，2,000 次
  resample，seed 与完整样本保留。CI 描述该固定主机/语料的采样不确定性。
  本结果属于开发机观测，不能作为 dedicated-host acceptance 或行业领先结论。
- RSS 是整个 child 的 peak，包含库、调用方缓冲、校验和上下文；不等于
  codec-only heap。完整 stderr/RSS sidecar 与原始 structured probe JSON 均归档。

原始 child stdout 的全部字段保留在精确 row JSON 的 `probe` 中。Runner 没有
单独保存原始 stdout 文本字节；归档中的独立 stdout JSON 是明确标记的派生
视图，不声称其排版就是原输出。

[aggregate-summary.json](modern-decode-refresh-20261111/aggregate-summary.json)
保存全部 72 行汇总与 CI；
[summary.json](modern-decode-refresh-20261111/summary.json)保存尺寸/生命周期组；
[validation.json](modern-decode-refresh-20261111/validation.json)绑定所有原始行、
源码、probe、库和 fixture。源码的 **2,029 个文件**与 `ea193be2` 的 Git blob
一致，主工作树的 dirty DirectChunk 源码没有用于此次校验。

参考库二进制与构建 provenance 按 SHA 复用
[原参考包](modern-decode-current-20261111/README.md)，避免重复存放二进制。
这份 fresh 结果完整保留自己的 source/probe/sample epoch，不将与旧 epoch
的数值差直接归因为 codec 回退。
