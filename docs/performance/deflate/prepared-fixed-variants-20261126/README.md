# Prepared fixed V2 / V3 rejected screens — 2026-11-26

此包封存 reserved-sink（V2）与 direct-bit（V3）的完整实验。每个变体包含
540 条成功样本、45 个统计行及 6 组 AB/BA 配对；两个结果均为
`accepted=false`。归档完整性通过不改变原始性能判定。

| 变体 | 24 个目标行 GM | 配对 95% CI | 低于 0.98x 的控制行 |
| --- | ---: | --- | --- |
| V2 reserved-sink | 1.1810077856704524x | [1.1766280264326079, 1.1861752109592463] | small：mozilla.256、nci.256、ooffice.256；legacy：mr.65536、reymont.65536 |
| V3 direct-bit | 1.2566460532042603x | [1.2539276432004445, 1.259706593295646] | legacy：mozilla.65536、mr.65536、reymont.65536 |

测试使用 Intel Core i7-10700K、Zig 0.16.0、ReleaseFast、
`x86_64-linux-gnu` / `skylake+pku+sgx`，单线程固定 CPU 2。
基线源码为 `8ccd54a59da850da724cc4d6ca79a727c659889e`；这是 Vort
公共 append API 的匹配暖态比较。完整 host、输入、压缩大小、参数及
生命周期保留在各变体 manifest、raw 和构建收据中。

基线及 legacy 控制调用 `RawDeflateEncoder.encodeFixedWithOptionsAppend`；
prepared 调用 `PreparedRawFixedEncoder.encodeAppend`。准备、调用者容量
预留及一次 warm encode 在计时外；计时包含每轮 `clearRetainingCapacity`、
完整公共 append 和 length mix。hash 参数为 window=16384、min_match=4、
max_chain=32、nice_len=16、max_match=128、max_candidates=2。
全部样本保留，未删离群值，未重试成功样本。

`v2-reserved-sink.tar.gz` 与 `v3-direct-bits.tar.gz` 分别保留冻结源码、
ELF/probe/编译收据、99 个采样前比较 wire、66 个新 public-preflight wire、
264 条外部进程记录、66 条 Python 解码收据、原生与实际 WASI gate、
codegen、source-before/after、判定及完整 raw/chronology。
仅排除编译缓存和 V2 runner 字节码缓存；两个冻结源码清单中的既有
`src/.../__pycache__` 文件均保留，源码身份仍为 2,216 个文件。
`common.tar.gz` 保留原始基线源码 tar、被引用的 V1 拒绝证据及参考身份字节。
`archive-bindings.json` 列出每个归档及成员的大小、SHA-256、来源和排除项。

V3 首次权限失败保存在 `performance/launch-failure-permissions/`：
一条 taskset 失败记录，退出 126，零个成功启动的 codec 和零个计时样本。
组名验证器失败保存在 `performance/verification-group-name-failure/`；
修正后的验证器及实际 exit 0 同时保留。V3 `copy-failure.json` 也原样保留。
这些历史失败未替换或删改完整成功样本。

运行离线验证：

```sh
python3 -B docs/performance/deflate/prepared-fixed-variants-20261126/verify.py
```

也可复制整个目录后在任意位置运行 `python3 -B /copy/path/verify.py`。
验证器只读取当前包、在内存中读取 tar，不解包或调用记录中的 argv；
它核对文件哈希、源码、构建和终态收据、容量/参数/时序、wire 字节一致性，
再调用从 V1 包逐字复制的 `independent_statistics.py` 重算配对比值、
20,000 次确定性 bootstrap CI 及 0.98x 行门槛。

解码和零堆请求行为只核对已有验证收据；本次未执行 codec、编译器、
反汇编器、外国参考程序/SO 或计时。计时没有测量 RSS；静态 emitter
codegen 不构成性能验收。两套 screen 均未通过控制行门槛，未获准采用，
采用前仍需新的完整源码验证。本包不作行业性能声明。
