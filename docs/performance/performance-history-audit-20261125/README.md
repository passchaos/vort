# 编码性能历史口径审计，2026-11-25

这份包保存历史证据并统一重算，不执行 codec、构建或新的 benchmark。
**Brotli q8 同数字 preset 的跨 epoch 延迟确实明显增加，同时 wire 更小；
这些数据尚不能判定同 harness 下的源码因果回归。** Deflate L9 的这组
64 KiB 历史对照没有显示整体变慢。当前差距不能全部归因于统计口径修复，
也不能由这些旧新 epoch 数字直接归因于某个提交。

## 本包能够离线重算的主结果

每个 codec 使用同一组十二份真实 Silesia **65,536-byte 前缀**，不重复、
填充或使用 synthetic 输入。`inputs/` 保存完整 plaintext；脚本逐份检查
旧、新样本的长度与 SHA256。所有表中倍数为耗时比，较小更快。

对每行所有 measured raw rounds，先把 `elapsed_ns / iterations` 统一为
每次调用的耗时，再取中位数；最后给十二行相同权重，计算比值几何均值。
预热不参与这些中位数，没有挑最快轮次。旧 Brotli 每行有三 sweep × 五
round，共十五个 measured pairs；新版每行五个 pairs；双方 iterations=3。

| 同 64 KiB cohort，统一 raw-median 口径 | 可复算结果 |
| --- | ---: |
| Brotli q8：新 / 旧 Vort 编码耗时 | **3.66687054x** |
| Brotli q8：旧 Vort / 同参考库耗时 | 18.03526784x |
| Brotli q8：新 Vort / 同参考库耗时 | 73.49883186x |
| Brotli q8：新 / 旧 Vort encoded size | 0.95658086x |
| Deflate L9：新 / 旧 Vort 编码耗时 | **0.92571534x** |

`summary.json` 保存十二行全部数值。三个 q8 代表行如下，毫秒是每次
ordinary allocating 调用的中位数，不包含文件读取或输出验证。

| 输入 | 旧 Vort ms | 新 Vort ms | 新 / 旧耗时 | 旧 / 新 wire bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 33.912601 | 115.632015 | 3.409707x | 24,723 / 22,367 |
| mozilla | 37.561586 | 166.492088 | 4.432510x | 14,216 / 13,924 |
| nci | 25.901184 | 97.216820 | 3.753374x | 4,390 / 4,206 |

审计初期的 **3.66578308x** 同样能够重现，但它使用旧 CSV `candidate_ns`
的“每个 process 中位数，再对三 process 取中位数”，而不是统一合并十五
个 raw rounds。它留在 `summary.json` 的 `geomean_new_over_legacy_csv_vort_time`
中，主表使用统一 raw-median 的 3.66687054x。差别不能被隐去或误称为
same-harness 采样误差。

旧摘要的 30.086271x 对应 **4/16/64 KiB 三个尺寸、36 个真实输入**的单独
参考 epoch，不能拿来与今天单一 64 KiB cohort 比较。本包保留原摘要和
来源文档以识别其范围；不从这些 64 KiB 文件声称重算完整三尺寸数字。
本文的 18.035268x 来自本包保存的实际 64 KiB 原始样本。

## 可比项与仍然不同的项

- 十二条 Brotli 旧、新输入 SHA256 全部相同；三份 libbrotli **1.2.0**
  encoder/decoder/common 文件 SHA256 全部相同，文件本身也保存在
  `references/`。十二份参考 initial-wire SHA256 全部相同。这里只核验
  保存的请求文件与 report，不把其哈希当作动态加载器全部依赖闭包证明。
- 旧、新 q8 都是 ordinary allocating one-shot，quality8、generic、实际
  wire window16、`vort_hq_enabled=false`，command-state 的 255 是保留
  quality schedule 的 sentinel。它们不是 warmed reusable/prepared context
  benchmark。编码、输出分配及释放在计时内，输入、哈希、initial-wire
  解码验证和 JSON 在计时外。
- **旧窗口请求为 null，新窗口请求为 explicit16。** 相同实际 wire window
  不证明 candidate graph 相同。旧 reference 没有 batch 前 encode warmup；
  新 reference 和 Vort 都在各自 timed batch 前做 untimed encode。完整
  `timing` 和 `settings` 保留在每份 report 与汇总中。
- 旧 epoch 为 i7-10700K / CPU2，新 epoch 为同机 / CPU15；两边声明
  Zig0.16 ReleaseFast、GNU x86-64、`skylake+pku+sgx`。新版记录
  intel_pstate/powersave、turbo 开启，是开发机测量。固定 affinity 不等于
  dedicated-host 验收，也不证明无背景负载。原 CPU15 矩阵和其 load/运行
  范围说明保留在来源文档及 manifest；这次审计没有新做 load 观测。
- 新数字固定在 `4a9796b01aa0617aace28d2d4ca2c83cb81b409a` 的编码 epoch。
  原 manifest 的 `complete=false` 保留，表示完整文件 cohort 仍未完成。
  本包只重算两 codec 的 64 KiB 部分，不推广至 1 MiB 或完整文件。
- Deflate 比较 Vort L9 / libdeflate1.26 L12。十二条 input、Vort initial
  wire 与 reference initial wire 的长度、SHA256 均旧新相同；脚本从旧
  stdout 的实际 ns 和新六轮 raw ns 重算中位数。CPU/epoch 与旧参考状态
  生命周期仍不能当作同 harness 匹配。0.925715x 不证明源码带来 7.4%
  加速，也不支持这组 Deflate 整体变慢。数字 level 不是等质量契约。

## 精确旧源码和明确的策略变化

旧 candidate codec 源码精确对应
**`0a673757ea6a1e88b90794ad44dce1a8a824f371`**，不是 proxy。
`source/old-q8/source-final.tar.xz` byte-preserves 当时完整 1,807-file 快照，
SHA256 为 `666139da5599002b9d48670f50a979265c696eae5da48c5af30f80c41fc38633`。
对应 manifest 与 `build-bench-final.json` 完全相同。1790 个 tracked
source/build/tool 文件已与该 Git 提交的 blob 逐份核验；17 个不在 Git 的
文件全为 tools/br 的 Python bytecode。生产源码没有缺失或不匹配。
`git-bindings.json` 保存匹配的 Git blob SHA1，离线脚本从 archive 字节
重新计算 SHA256 和 Git blob SHA1。该脚本不需要 Git 仓库。

旧 report 的 benchmark SHA 与 build receipt 一致：
`a376f64d12ddde145336893459946b485736eeab21a28cea59a368b39b4a0018`。
原 tool 构建命令链接 `record.o`，其 SHA 与 argv 留在 build receipt；
本包没有执行或重建该 ELF，也不把报告中的 ELF hash 当作新执行验证。
新 epoch 的 source/probe 标签来自保存的 checkpoint manifest；本包不
独立重建新 epoch 的全部 codec 源码或可执行文件。

保存的 `source/q8-q9-entropy-feedback.patch` 是提交
`cf4e870cc69d60e4d2227dd3227f3c138312ccde`（2026-11-05）的实际 Git diff，
其中 q8/q9 从默认 false 改为 `entropy_feedback=true`。文档同时记录
affected text rows 的时间增加。当前显式 window16 profile 文档记录四次
optimal-parser events。它们说明后来 preset 的工作量发生了变化，**不能
证明此次 3.66687x 增长全部来自 cf4e870c**；仍有后续源码、窗口请求、
warmup 与 CPU/环境差别。

## 来源与离线复核

最关键的五组来源均有本包内副本：

1. `sources/br/command-model-lifetime.md`、旧 CSV、`raw/brotli/old/`：旧 q8
   actual-window16 allocating matrix，以及后续 entropy-feedback 行为说明。
2. `sources/modern-encode-refresh-20261125/README.md`、保存的 checkpoint
   manifest 与 `raw/*/new/`：4a9796b0 当前 epoch、所有 raw rounds 和边界。
3. `sources/deflate-bt-optimal.md`、`raw/deflate/old-live-comparison.json`
   与 refined-history 文档：旧 Deflate 编码近参考主要是 size；后者没有
   完整最终 five-pass policy 的匹配速度矩阵。
4. `sources/zstd-hq-auto-level-policy.md`：旧 opt-in native HQ/64 KiB 行
   与今天 public level policy 不是同策略；旧 legacy95 snapshot 还被撤回。
   本包没有新作 Zstd 计时或从这些不同策略推断回归。
5. `sources/mainstream-gap-snapshot-20261111.md`：接近 0.94/0.78 等旧值
   分属解码及旧系统参考；不能与今天编码吞吐比较。旧满文件 Brotli 的
   0.2777 是 throughput ratio，不是表示加速的 time ratio。

`capture.json` 记录每个复制文件的原始路径、完整字节 SHA256 与大小。
`SHA256SUMS` 覆盖整个包；`verify.py` 只读取包内文件，不加载或调用 SO、
codec 或历史脚本，不读原工作区。可把目录复制到任意位置后执行：

```sh
cd docs/performance/performance-history-audit-20261125
sha256sum -c SHA256SUMS
PYTHONDONTWRITEBYTECODE=1 python3 verify.py
```

脚本验证 raw 轮次、排列、length mix、输入/参考/wire hashes、旧源码
archive 和 Git blob 绑定，然后重算并严格比较 `summary.json`。使用显式
exception 检查，`python3 -O verify.py` 也执行同样的验证。

实际验证已通过普通模式、`-O` 模式、全部 SHA256，以及复制到独立目录
后的 `-O` 离线重算；两项语义负例确认缺失 round 和错误 length mix 都被
拒绝。`verification.json` 保留执行结果和范围。

下一步应固定同一 minimal allocating q8/generic/**explicit16** probe，
分别接精确旧源码 0a673757 与新源码 c2c8f250；先用 dickens/mozilla/nci
三条 64 KiB，再扩展十二条 corpus controls。先用旧 null-window 请求
做独立 untimed frozen-wire 对照，确认重建来源；formal A/B 双方固定
explicit16、相同 warmup、alloc/return/free、Zig target 和 iterations，
在 CPU2 上 AB/BA 交替保存全部 samples。该 probe 不需要参考库计时。
这份包尚未执行该 A/B，也没有回退质量策略。
