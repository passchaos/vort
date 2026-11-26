# 四 anchor 完整候选图：容量拒绝 — 2026-11-27

冻结源码为 `92204434b194bd4e87cf6349cbd6bfaac64ea5da`。12份64 KiB输入
实际计数 **15,261,027 个 policy-admitted LZ edges**；独立重算的 raw graph
容量合计 **64,189,884 B**，lossless run 表示合计 **52,750,076 B**。
这些是12个独立输入的容量估算求和，**不是同时峰值、codec峰值或吞吐测量**。

Raw表示按每edge4 B及每输入u32 offsets[n+1]计算；run表示按原顺序、相同
length与等差distance保留全部边，raw操作4 B、run操作8 B。Owner metadata、
前驱索引、allocator bookkeeping和remap瞬态不在估算内。原helper只保留
一行最多64edges，没有分配完整图；run也只是抽象表示估算。

**直接完整graph方案因内存增长风险未实施。** 此拒绝不证明任何吞吐收益，
不批准run压缩/DP replay实现，也**没有修复历史q8耗时回退**。

原完整source.tar、2220文件清单、helper、binary、12行raw、原verify脚本、
输入及build/runtime回执全部保存。提取树与完整tar逐字节核对后不重复存储；
原证据未修改。原helper的ReleaseFast构建/计数exit0按回执验证，本次不重跑。

```sh
python3 -B docs/performance/br/known-match-graph-capacity-20261127/verify.py
```

也可复制整个目录后运行 `python3 -B /copy/path/verify.py`。验证器只读包内字节，在内存
中读tar；独立核对源码/输入/原artifact哈希、逐行edge/run/offset守恒及总和，
不执行原helper、codec、producer、foreign library、build或计时。它不重新
证明未保存逐edge列表的最短run分段；该重建检查属于原helper的已有执行范围。
