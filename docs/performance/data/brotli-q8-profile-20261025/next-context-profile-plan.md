# Preferred-context 下一项 profile 与保持输出的优化

建议下一项仅做**单次 chooseProposals 内的精确 tree-score 缓存复用范围扩展**，
并先把 preferred-context scope 分到真实的 recent-distance scan 和 proposals
调用。现阶段不改冻结源、不编译、不计时；本文是对子模块实现的只读分析。

## Smoke 说明了什么

父任务首次 Mozilla64KiB smoke：outer 98.885ms，preferred_context exclusive
68.088ms，wire 17.809ms / 18 attempts，optimal parse 7.839ms、lazy 1.202ms、
split 1.681ms、distance 1.831ms，54 events，full wire coverage，分类99.93%。
这次发生在并行编译环境，不能用它宣称 quiet 倍数或稳定 CPU 热点占比。

`encodePreferredCommandPlanAllocRecorded` 的 exclusive 已扣除了 wire 子事件，
所以它确实将主要待解释成本定位到候选准备/判断区域。但68.088ms还包含
`countReusableRecentDistances`、primary/context 设置、`chooseProposals`、去重、
selection、stats/context bookkeeping 和释放；它不是 chooseProposals 的单独时间。

## 已存在的优化，避免重复立项

实际模块是 `src/br/encoder/literal_context_split.zig`：

- `chooseProposals:207` 用 `collectAnalysis:386` 一次生成四个RFC mode的
  64-context histograms，共享全literal histogram和active-symbol support，
  baseline tree成本也只算一次。不能建议“先把四mode收集合成一遍”，它已做。
- `chooseModeFromHistograms:481` 的suffix枚举是增量累加left histogram；
  空context cutoff复用上次payload cost，suffix map成本有静态表。
- clustered搜索先构造稀疏contexts；`clusterContexts:598` 每轮冻结
  `prepareAssignmentCosts`，按稀疏symbol计assignment，迁移频率只是准备下一轮。
  不能改变成边迁移边重新评分，那会改变本轮顺序、tie和输出。
- 每mode有22-entry `ScoredMapCache`，key为context_map、tree_count，避免
  已收敛重复map的完整评分；还有128-slot `TreeScoreCache`，hash后再比较完整
  `[256]u32` histogram，复用树的完整bit cost。
- `treeBitCostProfiled:913` 已用全局active support，独立计alphabet、lengths、
  weighted payload、prefix。较大alphabet的prefix进入complex-prefix/RLE与
  code-length-tree评分；不能把tree score只理解为求一组Huffman lengths。

一个mode至多尝试11种requested tree counts（2…64）×ordered/interleaved两seed。
稀疏context数量不足会提前退出；合法trial最多4/2/1轮，并可不变时提前停止。
四mode、lazy和optimal两套计划可累积很多评分，但源码上限不证明Mozilla
实际执行了所有trial。

## 唯一优化：共享 exact tree-score memo 的生命周期

当前 `TreeScoreCache` 在 `chooseModeFromHistograms:531` 创建，每个mode重置。
cluster评分会使用它，而 `suffixPayloadBitCost:561` 的left/right树直接评分，
不走该memo。因此相同完整histogram可能跨mode、suffix/cluster路径被重新求
alphabet、code lengths和complex-prefix cost。

将一个固定容量128-slot的tree memo移到**同一次 chooseProposals 的 Analysis
生命周期**，由baseline/suffix/cluster共同使用；四mode保持原顺序。
不增容量，不跨input、command plan、调用或线程复用。先测实duplicated score
的数量和加权成本，再实施这一范围扩展。

其保持输出的理由是缓存值为原来的精确u64 tree bit cost。在这一调用内
active-symbol support恒定，histogram由同一不可变Analysis导出；hit必须同时
通过hash和全部256项频率相等。miss调用完全相同的原评分器，成功后才put；
OOM等错误直接传播，不保存部分结果、不用近似评分、不更换fallback。

保留所有cutoffs、requested counts、seeds、rounds、固定assignment costs、
candidate比较顺序和严格更优的tie规则。不要复用已经挑出的context proposal
来跳过mode或trial。更长生命周期可能引入额外冲突、降低部分mode内hit率，
所以“已有cache扩范围”并不保证加速，必须用false/unobserved计数版本验证。

**不要一起跨mode共享 ScoredMapCache。** 它的key没有mode或输入histogram；
同一个context_map在另一个mode下可聚合出不同频率。现有per-mode作用域使
它安全，直接提升作用域会缓存错误结果。此次只扩精确histogram树评分memo。

## 需要增加的细分测量

先在q8真实preferred调用点增加两个子scope：

1. `recent_distance_scan`：仅countReusableRecentDistances。
2. `context_proposals`：仅实际chooseProposals，记录lazy/optimal plan来源、
   command/literal数量和proposal配置。剩余preferred exclusive继续保留，
   不将其差值悄悄记给chooseProposals。

随后使原chooseProposals共享一个 `comptime profiled` 核心，诊断调用返回
**实际要用的Proposals**并写入caller-owned detail。现有profileSearch的代码
可提供计数/阶段方案，但不能先调用profileSearch再调用chooseProposals：那会
重复完整搜索、改变outer工作量。现公开profileLiteralContextSearch先构造的是
legacy ratio optimal plan（256/258/128预算），也不能直接代替q8 actual lazy
或128/192/64 optimal commands。

复用已有detail阶段：analysis、baseline、suffix、sparse、cluster init/prepare/
assignment/finalize/score；树评分alphabet/lengths/weighted/prefix；small-Huffman
和complex-prefix子阶段。它们有包含关系，只用于层级展开，不能把
cluster + cluster_score + tree_score + prefix相加。每层独立保留unattributed。

针对这一个memo建议加以下caller-owned计数（不加clock per query）：

- 按mode与评分来源记录请求、hit、cold/conflict miss，score执行次数。
- 跨mode和suffix↔cluster的**完整histogram相等**复用数；hash相同不算证明。
- unique exact histograms、被重复评分的累计时间、评分alphabet大小bucket。
- baseline/suffix/cluster耗时与原tree_score调用数，验证没有把漏计改成收益。

扩memo后普通路径应关闭可观察Work；diagnostic计数和无观察计数的执行体分开
说明。既有Zstd anchor实验已经证明profile计数可改变局部收益，不能再用
观察计数版本的速度推断普通编码成本。

## 未来实现范围与验收

建议代码所有权仅涉及 `literal_context_split.zig`、`literal_context_profile.zig`
和q8 preferred的诊断接线；独立测试文件负责reference cache-disabled比较。
不改q8调度、wire writer、字典、其他codec或已有golden。

验收先验证每个mode的suffix/up-to-16/full proposal（mode、tree_count、64项
context_map、savings_bits）与原评分路径一致，再验证完整q8 frozen14 wires。
加入故意hash collision、cache replacement、跨mode同map不同histogram和
suffix/cluster相同histogram的定向测试。比较失败清理与总预算，不要求旧
allocation-index完全相同，因为合法hit可减少原评分器的临时分配；不得吞
WorkingMemoryLimitExceeded或把错误当不利候选。

只有在原q8/full-profile tests及差分通过后，才在quiet CPU8交替五轮测Mozilla
和source控制，再复查frozen14整体wire、ratio、heap和速度。当前没有新增
deep profile数据，也不承诺68ms全部可节省或会提升任何固定倍数。
