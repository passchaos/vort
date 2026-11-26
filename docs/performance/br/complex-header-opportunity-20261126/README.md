# Complex header 完整 key 机会诊断 — 2026-11-26

此包封存临时 observer 的完整成功捕获与离线 memo 模拟，原 builder、
候选、TreeScoreCache 和 ProposalWorkspace 仍执行原逻辑。结果是机会
诊断；Root 当前不优先实施 32 项 memo，没有把命中数换算为速度，也
没有采纳 Huffman 证书或其他优化。

| 范围 | 完整结果 |
| --- | ---: |
| 实际成功 header 请求 | 50,850 |
| 全局 distinct 完整 key | 33,650 |
| 每 analysis 重置：32 项 / 16 sets / 2way LRU | 3,374 hits / 50,850，6.6352% |
| 每个完整 quality operation 保留同容量 memo | 3,374 hits / 50,850，6.6352% |
| cross-analysis hits / unknown scope | 0 / 0 |
| 原 normal / trace 完整 wire | 12 / 12；全部与 gold 逐字节一致，两个 round-trip 均通过 |

key 为完整、零尾部初始化的 256 个 u8 lengths、stop index 和原始
policy id；analysis ordinal、scope、mode 只作来源元数据。FNV1a64 只作
prefilter，每个 hit 必须比较完整 key。所有相同完整 key 的原始 exact
header bits 一致。请求只记录实际成功 `bitCostSparse` 执行；没有为
原缓存已跳过的请求制造伪记录，也没有再次扣除既有复用。

原始基线为 `8ccd54a59da850da724cc4d6ca79a727c659889e` 的编译输入
闭包，另加六个临时 instrumentation 文件。q8 / generic / explicit
window16，Zig 0.16.0、ReleaseFast、GNU x86-64、`skylake+pku+sgx`，
i7-10700K、单 codec 线程固定 CPU2。每输入一次 normal + trace；未记录
per-header 时钟，原 profile ns 只用于诊断。

observer 的调用者存储一次预分配 131,072 × 280 = **36,700,160 B
（35 MiB）**，跨输入复用。最大实际占用记录空间 **2,599,800 B
（约 2.479 MiB）**，为 Mozilla 的 9,285 条记录。inline owner 56 B、
TLS pointer 8 B、ProfileState 178,464 B 分别保留；allocator bookkeeping
和 I/O/JSON 不在 payload 内。这是 codec 外的诊断 heap 声明，不是
encoder 资源测量或改善。完整 key 没有截断、overflow 或 header failure。

首次 build 已成功；首次 capture 在 codec 前以 `StreamTooLong` exit1，
0 codec calls。临时 driver 只把读取上限 65536 改为 65537 以检查 EOF，
`input.len` 仍须恰为 65536。首次与修正后的 ELF/build/capture 回执均
保留。首次 driver 从最终源码反向恢复这一个改动，字节 SHA 匹配原始
`old_driver_sha256`，并明确标记为恢复源码。该失败没有删改成功 raw。

归档分为：

- `sources.tar.gz`：原 partial baseline tar（2,992 个编译输入文件）、
  六文件 overlay、首次 driver、vail 依赖及 source epoch 清单。最终
  2,995 个编译输入可完整重建；不复制 docs 大归档或编译缓存。
- `evidence.tar.gz`：全部 `capture/header-*.json` 原请求、50,850 条
  `memo-request-ledger.jsonl`、diagnostic/summary/CSV、12 normal + 12 trace
  wire、gold/inputs、所有构建与 capture epoch、原 EOF 失败、4 项 Python
  exact-key 测试及实际 exit0 收据、instrumentation diff 和 builder 原样证明。

`archive-bindings.json` 保留归档/成员的 SHA、大小、来源与明确排除项。
`source/.zig-cache` 和分析 bytecode cache 排除；原始源码、请求、ledger
及回执不修改。该包不包含正在另一源码 epoch 开发的 adaptive distance
candidate。

离线验证：

```sh
python3 -B docs/performance/br/complex-header-opportunity-20261126/verify.py
```

也可复制整个目录后运行 `python3 -B /copy/path/verify.py`。验证器只读
包内字节，在内存中读取 tar；不执行 producer/analyzer、codec、参考
程序/SO、编译或计时。独立 LRU 使用每桶 oldest→newest 顺序重放，逐条
核对完整 key、exact cost 一致性、来源及两种 lifetime 的全部 ledger
步骤，再核对 per-input counts、CSV、总数、wire、源码及原始失败收据。
最初包内 source-path 适配遗漏及其修正另存 `verification-attempt1.json`；
这没有改变原捕获资料。

该容量下跨 analysis 保留没有增加命中。完整 key 的一致性与命中统计
没有证明缓存的吞吐收益；后续优化优先级仍应由新的完整操作测量决定。
