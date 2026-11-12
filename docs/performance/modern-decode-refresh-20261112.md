# 当前已提交源码的完整解码性能，2026-11-12

当前提交 `21e4a1d0c0323c7db2317fd6e7cda4c5069e8e1d` 的完整矩阵已完成。
Vort 的 cold 解码吞吐几何均值分别达到 libdeflate 1.26 的 **68.87%**、
libzstd 1.6.0 的 **76.58%**、libbrotli 1.2.0 的 **81.93%**，仍未追平。
这是固定开发机和固定语料对照，不能证明全行业领先。

| Codec / 参考版本 | Vort / 参考吞吐 | 95% 固定行吞吐 CI | Vort / 参考耗时 |
| --- | ---: | ---: | ---: |
| Deflate / libdeflate 1.26 | **68.87%** | 68.78%–68.95% | **1.4521×** |
| Zstd / libzstd 1.6.0 | **76.58%** | 76.47%–76.70% | **1.3057×** |
| Brotli / libbrotli 1.2.0 | **81.93%** | 81.83%–82.02% | **1.2206×** |

每个 codec 的 cold 汇总包含全部 72 行：十二份 Silesia、64 KiB/1 MiB/
完整文件、两档 producer level/quality。全部六对 measured samples 参与计算，
每个固定条件等权，没有挑选最小值或只报告改善行。

| Codec cold 耗时比 | 64 KiB | 1 MiB | 完整文件 |
| --- | ---: | ---: | ---: |
| Deflate | 1.5110× | 1.4210× | 1.4260× |
| Zstd | 1.2674× | 1.3408× | 1.3101× |
| Brotli | 1.2384× | 1.1570× | 1.2692× |

Zstd 在双方复用并 prime 的 `NativeFrameDecoder`/`ZSTD_DCtx` 生命周期下，
72 行吞吐为 **77.70%**，耗时比 **1.2870×**。Deflate 的额外 72 行只复用
参考 decompressor，Vort 仍调用相同 one-shot API，明确标为
`reference-only-prepared`，吞吐 **68.87%**、耗时 **1.4519×**；不能称双方
prepared 能力相同。Brotli 当前 probe 没有可匹配的 reset/reuse API，未产生
prepared 行。

| 最弱 cold 条件 | Vort / 参考吞吐 | Vort / 参考耗时 |
| --- | ---: | ---: |
| Deflate：mr，64 KiB，L9 | **60.35%** | 1.6570× |
| Zstd：mozilla，1 MiB，L3 | **59.91%** | 1.6691× |
| Brotli：mozilla，完整文件，q11 | **48.46%** | 2.0636× |

Cold 的含义是每次公开调用的上下文生命周期；caller 缓冲提前分配，文件
读取、动态库加载、校验和输出发布均在计时外。Vort 调用公开 caller-buffer
API；Deflate 参考的 allocate/decompress/free 在每次计时内，Zstd 使用
`ZSTD_decompress`，Brotli 使用包含状态初始化和清理的
`BrotliDecoderDecompress`。这不是进程启动或磁盘 cold-cache 测量。

本轮全部 **360 行**正常完成：216 cold、72 Zstd matched prepared、72
Deflate reference-only prepared；保留 **2,160 measured pairs** 和 **720
warmup pairs**，AB/BA 顺序平衡。216 条 wire 和 36 份 plain 均复用原冻结
文件与 producer/hash/size 元数据，没有重新压缩。Deflate wire 的生成器
是 Python zlib 1.2.11 raw L6/L9，解码参考是 libdeflate 1.26。

每次检查返回长度，每批检查完整输出、64-byte guards、输入和 wire 不变。
两边 Deflate 都核对精确消费量；选定的 Zstd/Brotli one-shot API 不暴露
消费计数，该范围不被扩展。原始 child stdout/stderr 字节、RSS sidecar、
命令、库映射集合与 host observations 逐行保留。

主机为 Intel i7-10700K，逻辑 CPU15；Zig 0.16.0 ReleaseFast，
`x86_64-linux-gnu`、`skylake+pku+sgx`，单线程。参考版本与源码修订、GCC
编译选项、SO 哈希、实际 loaded closure 和 power policy 全部固定并校验。
所有 child 边界没有观察到 compiler。进程 tick/last-seen CPU 信息不证明
它们与具体 timed batch 的重叠，结果仍是开发机观测。

95% CI 使用固定行、按 Vort-first/reference-first 分层的 paired log-ratio
bootstrap，2,000 次 resample。原汇总的行迭代顺序也保存：有限 bootstrap
的 CI 会随同一 seed 下的 row 顺序略变，不能用另一个排序的 CI 冒充原件。
尺寸组和全 codec 组的各自原 seed 均保留并独立重算。CI 描述本机固定语料
的采样不确定性，而不是跨主机或全行业置信区间。

此前 `ea193be2` 矩阵和本轮数值差不能直接归因为 codec 加速。本轮包含后续
功能修复和已提交 benchmark 工具源码的实际状态；未采用的 owner/copy
原型全部留在独立工作树，未计入此排名。当前 probe SHA 为 `a69c106f...`。
最初 CPU0-only runner 的 available-affinity 检查失败发生在任何行采样前；
原日志保留。修正使用初始 `{0,15}` 验证，再将 runner 留在 CPU0，每个 codec
child 独立 pin CPU15；该启动修正不被标为 codec 失败。

完整来源与离线核验见[证据包](modern-decode-refresh-20261112/README.md)。
下一轮优先采用已核对参考实现中的计划所有权、最终执行表生命周期和
有界 fast-path 证明，并用新的完整操作数据验证；不能把参考源码机制或
局部候选收益当作当前主线性能。
