# 当前 Brotli / Zstd 编码首轮基线

日期：2026-10-25。源码 `d4297483`，Intel Core i7-10700K，Linux x86-64，
Zig 0.16.0 ReleaseFast，native CPU，单一 CPU 8。每种 codec 一个 process，
相同的十四份冻结 64 KiB 前缀，每行五轮交替编码，iterations=1。

这轮数据用于选取优化对象。它不证明完整档位、输入大小、内存或平台上的
领先；相同级别编号也不代表两库使用相同算法和有效参数。

## 当前结果

| 指标 | Brotli q8 | Zstd level3 |
| --- | ---: | ---: |
| Vort 压缩大小领先行 | 9/14 | 13/14 |
| Vort 吞吐领先行 | 0/14 | 0/14 |
| Vort / reference 总压缩字节 | 288091 / 296445 | 310437 / 328241 |
| 总压缩字节减少 | 2.818% | 5.424% |
| 十四行中位吞吐比的几何平均 | 0.028209652 | 0.000551817 |

大小比较分别用两库自己的 encoder。吞吐比为 reference 编码耗时除以
Vort 编码耗时，两者处理相同长度的输入。原 CSV 保留独立最小耗时；此文
从 JSON 的全部原始轮次取各实现中位数，不把最小值混为中位数。

| 代表性慢样本 | Vort 中位编码时间 | Reference 中位时间 | Vort / reference 压缩字节 |
| --- | ---: | ---: | ---: |
| Brotli q8 Mozilla | 96.226670 ms | 1.543179 ms | 14216 / 13646 |
| Zstd level3 XML | 63448.242921 ms | 0.093473 ms | 5078 / 6099 |
| Zstd level3 MR | 54127.506423 ms | 0.266367 ms | 16806 / 17527 |
| Zstd level3 仓库源码 | 15729.365060 ms | 0.173597 ms | 12111 / 13601 |

Brotli 的十四行吞吐比范围为 0.016037…0.044969。Zstd 存在显著的样本差异：
有些行耗时约 10…75ms，有些达到数秒或一分钟。压缩更小的结果没有抵消
这些延迟，因此下一轮应优先调查实际候选规划和重复成本计算。

## 参数与参考身份

Brotli 调用公开 one-shot quality policy：q8、generic、默认窗口16。参考
调用 `BrotliEncoderCompress`：q8、generic、lgwin22。参考为本地源码
`558fc647` 的 libbrotli 1.2.0-dev，Release `-O3 -DNDEBUG` 与
`-DBROTLI_EXPERIMENTAL` 构建，三库均用显式完整路径。

Zstd 调用 `zstdEncodeFrameWithLevelAlloc` 的完整 level3 policy，包含它
既有的 primary/split 候选仲裁。参考调用 `ZSTD_compress` level3，为本地
源码 `01b7154f` 的 libzstd 1.6.0。JSON 的 `resolved_primary` 只描述主配置，
另保存实际帧头，避免把主配置当作所有内部候选的配置。

运行时版本、显式文件与可执行文件 SHA 都在原始报告中。进程映射记录
包含所请求的参考库路径；实际符号和完整传递依赖来源仍未验证，不把
文件身份或映射路径解释为加载器闭包证明。

## 验证与测量边界

两种 codec 的实际输入、wire 长度/SHA、各70个原始轮次、顺序、mix、
最小值/中位数、CSV、可执行文件和显式参考文件通过独立 sample gate。
原 benchmark 的跨库解码校验在计时之外。输入来自 Silesia 十二文件和
仓库源码/JSON，均取实际 64 KiB 前缀；未用重复或填充增大输入。

Brotli process 在 2026-10-24 19:34:01…19:34:16 UTC 运行，136次监控未
观察到 Zig 进程。Zstd 在 19:34:16…19:50:03 UTC 运行，8821次监控未
观察到 Zig 进程。控制器固定在CPU6，编译任务全部结束后才开始测量。
此监控只证实所记录的 Zig 观察，未声称硬件完全没有系统噪声。

每行只有一次 process 内的五轮，稳定幅度与领先结论需要重复测量。
本轮不测 requested heap、独立实现 RSS、硬件冷缓存、incremental API、
完整文件、其他档位或 ARM64。当前数据不支持“业界最佳”。

十四行逐项数据见 [Brotli](data/current-encode-baseline-20261025/brotli-analysis.json)
及 [Zstd](data/current-encode-baseline-20261025/zstd-analysis.json)。
[证据索引](data/current-encode-baseline-20261025/index.json)保存两种 codec
的命令、140个原始round、CSV/JSON、输入身份、监控及报告完整字节。

后续先在同一慢样本上分离实际 family 成本。静态审查发现64KiB超过现有
duplicate index 的65535输入上限，但它是待验证候选；不能仅调上限，
因为计数宽度、匹配长度哨兵、suffix配对和成本shortcut都需要等价证明。
优化必须保持输出正确和质量，随后用同一输入重新做安静测量。
