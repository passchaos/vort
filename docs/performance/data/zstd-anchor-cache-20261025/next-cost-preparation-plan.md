# 下一增量：维护总频率与 active count

本轮只读源码和已有实验产物，并写入本报告；未编辑源码、编译、编码、计时或执行 Git。读取工作目录为 `/home/passchaos/project-z/vort-zstd-anchor-cache`，初次记录时间 2026-10-25 15:32:31 Asia/Shanghai（07:32:31 UTC）。父任务继续完成 anchor-cache 的诊断和拒绝默认分配结论，本报告不重跑当前验证。

唯一建议的下一增量是：在受控 init/update 生命周期的 histogram 内维护一个固定 `[256]u32` 总频率数组和 active count，随已有 stream byte add/remove 同步更新；内部 preparation 从新鲜、借用的 ready summary 取得频率和 unique，省去每次四流合并。保留原四流数据、公开 `PreparedLiterals`、原独立 `Certificate.analyze` 的完整验证及其 scalar reference。先不把 preparation 与 certificate inspection 融合为一个新计价路径。

## 当前证据和范围

读取的 [experiment-analysis.json](/tmp/vort-zstd-anchor-cache-20261025/experiment-analysis.json) 是三个 65,536 字节输入、每配置五次交替完整 candidate-stage 运行的已有结果。cached 时间包含两次 allocation、全部 hash 准备、length 初始化、所有 suffix queries 和 emission；它是带计数的 stage 实验，不是公共 API 速度结论。

[experiment-result.json](/tmp/vort-zstd-anchor-cache-20261025/experiment-result.json) 记录 source/executable stable，128 次 compiler observations 中有编译器进程的次数为零。可执行 SHA256 为 `c6382712b17036e8dfd92c9d2bf3936fd4baccddf9583e78ed41dada65fc2424`。provenance 为 Zig 0.16.0、ReleaseFast、x86_64-linux-gnu、`skylake+pku+sgx`，Intel Core i7-10700K，CPU8 单核 affinity、单线程 codec。以下是读取的计数，不是本轮新测量：

| 输入 | preparation / histogram updates Q | 原物理字节 add/remove S | S/Q | pruned | Huffman plans | bound checks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| silesia XML | 1,473,017 | 49,266,861 | 33.446 | 1,443,518 | 29,499 | 1,472,254 |
| silesia MR | 1,039,932 | 35,192,481 | 33.841 | 1,023,531 | 16,401 | 1,023,977 |
| Brotli source | 585,806 | 23,200,367 | 39.604 | 577,409 | 8,397 | 584,415 |

三组固定 `cache_state_bytes` 都为 6032。anchor cached stage 仅为 1.013850x、1.018848x、1.016185x，另外需要 393,174 字节 payload。XML 的 exact extension calls 为 49,943，hits 为 3,456,817；这一数值按 artifact 校正，不能把 hits 当作 calls。即使重复 extension 大幅消除，这些记录仍不足以证明某一个 preparation 环节的 CPU 时间占比。

## 要改变的具体工作

[prepareLiterals](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/single_cost_cache.zig:144) 每次先更新 cuts，再以 `totalFrequenciesAndCount` 合并 `[4][256]u32`，得到完整频率数组和 unique，随后按旧顺序计算 raw/header cost，并返回 [PreparedLiterals](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/single_cost_cache.zig:39)。

[payloadForWinner](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/winner_cost_cache.zig:54) 在判断 prune 前已经完成这个 preparation；因此上述三组的所有 Q 次都执行 histogram preparation，包含后来被剪枝的候选。[payloadLowerBound](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/winner_cost_cache.zig:100) 在自己的 gates 通过后，仍调用 [Certificate.analyze](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/weighted_bound.zig:73)，对真实完整数组检查 total、support、negative mass 和 bound。

所选增量只改变取得 preparation 总频率的机制：

```text
旧：update stream rows → 每查询四流 merge + active popcount → 完整 Prepared
新：update stream rows 时同步 aggregate → 复制 ready aggregate + 已维护 active → 完整 Prepared
```

Prepared 的频率字段仍为 1024 字节，新路线仍生成相同数组；witness 的完整分析仍继续读取该数组。这里不声称已经消除 1KiB 的物化或复制。源码返回数组也不能直接证明发布机器码每次执行完整 memcpy，LLVM 可能消除部分复制。

## 有界结构和借用边界

建议新增内聚的 `aggregate_totals.zig`，只拥有如下固定统计状态：

```text
frequencies: [256]u32
active: usize
ready: bool
```

它不持有 allocator，不拥有 block，不保存额外逐位置记录，不增加 stream/sequence/candidate 容量。受控 `CutHistogram.init` 从四流全零状态建立空 aggregate；原 update 的已有 byte add/remove 同时更新这一 summary。ready 是拥有方遵守生命周期的标记，不是任意外部频率数据的验证证明。

内部借用 snapshot 只来自当前拥有方完成 init 和成功 update 后的 histogram，包含 `*const [256]u32`、active、regenerated。借用有效期到下一次 update/re-init，输入 block 继续遵守已有 immutable borrow；各 cache 独占自己的统计状态。`single_cost_cache.prepareLiterals` 在一次已经 admission 的 update 后取得 snapshot，复制到原 Prepared 再按原顺序定价。

公开 `totalFrequencies` 和现有 `totalFrequenciesAndCount` 保留四流 reference/merge 行为，以继续支持其原调用与 oracle。新 snapshot 资格不能从 `Prepared.unique`、`Prepared.regenerated` 或 caller 提供的总数推断。未经过受控初始化的 histogram、直接构造的状态或无法在调用点证明其 init/update 所有权时，使用旧四流 merge；不能根据一个可伪造的 ready bit 让外部 plain Prepared 绕过验证。对 ready=false 的旧式状态，update 不擅自以新的全数组扫描 bootstrap summary，也不引入原 update 没有的错误。

公开 `literalCostPrepared` / `payloadCostPrepared` 继续按其已有输入和 histogram 一致性契约工作，不从新 summary 偷换 caller 的 Prepared；`Certificate.analyze`、`analyzeReference` 与任意 `[256]u32` 的 cap/overflow/error 处理完全保持。若后续需要零复制的 trusted view 或 fused inspection，应另开一个被明确证明的增量。

## 统计不变量和更新证明

对 symbol x，定义四个 stream 当前频率为 `F0[x]…F3[x]`，aggregate 为 A[x]，active 为 U。需要保持：

```text
A[x] = F0[x] + F1[x] + F2[x] + F3[x]
U = count(x where A[x] != 0)
```

初始化时两者为零。不改变已有 [applyDifference](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/cut_histogram.zig:77) 对每个物理字节的访问顺序，只在 [apply](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/cut_histogram.zig:89) 的现有操作中加入：

- add x：原 stream 频率加一；A[x] 加一；仅当旧 A[x] 为零时 U 加一。
- remove x：原 stream 频率减一；A[x] 减一；仅当新 A[x] 为零时 U 减一。原 stream 非零保证 aggregate 非零，不产生新的合法输入 underflow。

每完成一个 byte operation，两个不变量继续成立。完成整次 update 后，stream ranges 正是同一个 prefix/tail view 的 canonical one/four partition，所以 `sum(A)=regenerated`、每个 A[x] 不超过 N≤131072、U 与原 merge+popcount 完全相同。

必须处理一个容易遗漏的中间边界：1023/1024 stream transition 和其他 repartition 中，代码逐 stream remove/add，有些物理字节可能先进入新 stream，之后才从旧 stream 移除。中间 aggregate 可能暂时重复计算这些字节；不能断言每个中间值都 `<= current regenerated` 或 `<= N`。每个中间 stream 的频率仍不超过它的 old+new 集合，因而：

```text
中间 sum(A) ≤ old regenerated + new regenerated ≤ 2*N ≤ 262144
```

这仍安全落在 u32 内。U 在中间仍是当前 aggregate 的非零计数，最大 256；最终恢复真实 cut 的统计。不要把 frequency 缩成 u16，不要 clamp，不要重排原 stream 操作来迎合新的中间 cap。summary 只在 update 完成后发布借用，内部中间态不暴露给定价或 certificate。

## 错误、状态和输出顺序

[CutHistogram.update](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/cut_histogram.zig:42) 已在任何 rows/ranges mutation 前检查 cuts，以及 scanned_bytes/update_count 的 checked counter admission。所有这些返回错误继续发生在 aggregate mutation 之前，失败时整个 state（包含 aggregate）保持原样。

合法 byte operations 的新增 arithmetic 由上述 2N 和 support bounds 保证，不引入新可返回错误。Header/raw cost 失败发生在成功 histogram update 之后；新 aggregate 必须像旧 stream rows 一样保留已经准入的新 cut，不回滚或重复更新。现有 header-error oracle 明确要求 histogram update_count 只增加一次，见 [winner cache error tests](/home/passchaos/project-z/vort-zstd-anchor-cache/src/zstd/literals/winner_cost_cache_tests.zig:294)。

ready snapshot 不可用时，应在同一次已经完成的 update 内改取旧四流 merge；不能重新调用 prepare/update 作为 fallback。prepare 的频率、unique、regenerated、raw_cost 与原值一致，所以下游 bound 数值、support、negative delta、prune/null、Huffman inputs、tree cache、stream costs、certificate replacement 和计价错误顺序一致。finder 的候选及 winner 规则不变，因此 deterministic emitter 的 bytes 保持。

## 内存与源码级工作预测

native64 的 proposed summary layout 为 1024 字节数组、8 字节 active 和一个 ready 标志及 padding，保守增加 1040 字节。以本次记录的 6032 字节 cache 为基线，预计 native64 总 state 为 7072 字节，低于 8192。x86 的 active 更小；这只是计划布局，需要下一轮为 native Debug、ReleaseFast、x86 和其他受支持目标加入 `@sizeOf(Cache)<=8*1024` 硬验证，不能用推算代替编译后的结果。新增 aggregate 只在 cache 初始化时建立固定状态，无 query heap 和额外 source-byte scan。

现有四流 merge 对每次 Q 从源码上做 256 组三次 component addition；新 aggregate 在每个已有 source byte operation 上增加一次 aggregate counter update，以及一次 zero-crossing 检查/必要的 active 更新。沿用完全相同的 cut 操作时，新增 aggregate byte updates 的数量正好是已记录的 S：

| 输入 | 可移除的 component additions `768*Q` | 新 aggregate byte updates S | 保留的快照 |
| --- | ---: | ---: | --- |
| silesia XML | 1,131,277,056 | 49,266,861 | 每 preparation 相同的 256 个 u32 |
| silesia MR | 798,667,776 | 35,192,481 | 同上 |
| Brotli source | 449,899,008 | 23,200,367 | 同上 |

这些是按已有计数计算的源码级工作量，不是指令数、内存总线流量、cache miss 或 CPU 时间。vector component addition 与按 symbol 更新的 dependency/branch 成本不同；新 1KiB 状态也会影响工作集。原 witness inspection、精确计划及 Prepared 表示仍保留，不能依据这个表预测百分比加速或声称 preparation 已成为瓶颈。

## 首个实现和验证增量

实现只涉及 aggregate helper、CutHistogram 已有 add/remove 的同步维护和 single-cost preparation 的内部 ready snapshot。weighted/public analyze、winner 策略、sequence/emitter、levels、candidate caps 和 public 用户选项保持原行为。先保持独立的旧 merge preparation 作为诊断/reference，不同时融合 bound 或删除 Prepared 快照。

验证应以 old/new 状态和输出精确相等为接受条件：

1. 对全部 tiny prefix/tail transitions、empty/RLE/full-support、重复同一 cuts、随机变化、1023/1024、stream repartition 和 128KiB near-RLE，逐 update 比较 stream rows、reference merge、A、U、regenerated 与直接 concat-byte oracle。覆盖最后一个 symbol 移除、zero→one 和 one→zero，以及可暂时超过 N 的合法中间态。
2. 对 invalid cuts、scanned_bytes/update_count 溢出，要求包括 summary 的 deep state 完全不变；对 header failure 要求 exactly one update 和新 aggregate/rows 同步保留。检查 re-init 同地址新输入、借用失效、ready=false fallback，以及普通 u32 对齐和所有目标的 cache<8KiB。
3. old/new preparation 的完整 Prepared 值、Error!cost、每次 bound analysis、support/negative delta、prune、certificate age/replacement、Huffman plans、tree cache 和 finder winner 对照。手工构造的 Prepared/任意 frequency arrays 仍走原路径；已有 `InvalidFrequencyTotal`、overflow 和 malformed support 测试不可被 trusted summary 分支替代。
4. 沿用相同三组 65,536 字节 stage 输入和既有十四个 public wire hash 回归，要求所有现有 work counters 和 bytes 一致。新增统计只记录 aggregate byte updates、ready snapshots、fallback merges、state bytes，不通过减少候选或改变质量获取收益。
5. 在父任务协调冻结构建后，检查发布机器码中的 merge 消除和剩余数组物化，再量包含初始化、所有 updates、preparation、analysis 和 emission 的整 stage 成本及公共编码。不要只测 warm snapshot kernel；新增 scalar-per-byte 工作和 1KiB state 必须进入对照。只有整路径证据支持时再接入默认路径，若无收益则保留 reference 或撤回，不重复上一项因大 hit 数而推断收益的做法。

本轮建议降低的是每次 preparation 重新聚合固定四流的工作。它保留当前完整数组分析与验证边界，也保留候选数和 exact pricing 规则；下一轮实际性能结论由受控构建、机器码和整路径计时决定。
