# 公共收益不足时的最小回退设计

本报告是条件性只读方案：若父任务的公共对照不支持保留默认共享 tree cache，则恢复原 tree-cache policy，并保留本轮实际执行产生的 recent/context 细分诊断。当前候选源码仍冻结；本轮没有源码修改、编译、编码、计时或 Git 操作，也不提前替父任务作公共性能决定。

父任务已报告 Debug/x86/ReleaseFast 各75/75及完整family1421通过、一个skip；Mozilla smoke记录跨mode命中为零、suffix memo命中为零、跨scope命中lazy12/optimal7。这些局部计数不是公共收益结论。普通ELF中现有hits/misses更新与profile额外hash也不能直接转化成速度归因。

## 入口必须采用相同策略

保持一次Analysis的common core、四RFC mode顺序、原suffix/cluster proposal裁决和所有计分函数。用一个私有comptime默认policy常量，普通与公开Profiled入口都选择旧策略：

| 入口 | profiled | shared memo | 结果来源 |
| --- | --- | --- | --- |
| chooseProposals | false | false | 本次common core |
| chooseProposalsProfiled | true | false | 本次common core的实际Proposals |
| profileSearch | true | false | 每sample只调用一次上述Profiled |
| chooseProposalsReference | false | false | 原per-mode tree memo / suffix bypass策略 |

不能只把普通入口改为shared=false，却让Profiled/profileSearch继续shared=true；也不能先用共享策略profile再调用旧策略choose来取得结果。保留 [br.zig 的实际profiled chooser调用](/home/passchaos/project-z/vort-brotli-context-cache/src/br.zig:10235) 和返回的同一个Proposals，不恢复二次搜索。

还要覆盖single-mode入口：[chooseModeProposals](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/literal_context_split.zig:415) 当前有baseline/suffix共享memo，不能只改四mode core。将其恢复为直接baseline评分、直接suffix评分、sparse准备后建立per-mode cluster TreeScoreCache。`chooseProposalsForMode`、`ForModeWithPrefix`和任意max_tree_count的chooseUpTo路径继续保留原mode、initial_previous、候选上限及seed/round顺序。

旧cluster TreeScoreCache仍为128slots，ScoredMapCache仍每mode独立。恢复的是共享范围，不取消cluster memo、不提高容量、不删候选、不改变cost error/failure publication。共享实验的源码/统计/ELF与输入身份可归档为文本及证据；若保留隔离实验入口，必须明确实验policy，不让它成为公开默认profile的隐藏策略。

## shared=false 的直接评分也必须profiling

当前core的shared=false分支使用`treeBitCostWithSupport`，其内部固定`profiled=false`；suffix分支也固定走旧未profiling评分。因此只切换policy会让baseline/suffix树成本继续计时于外层stage，却从tree/simple/complex/alphabet/lengths/weighted/prefix计数中消失。

最小修复是增加或复用一个按scope记录的直接pure score helper，调用原`treeBitCostProfiled(profiled,...)`：

- baseline：common core直接评分一次，profiled=true时完整记录baseline tree work；mode为null。
- suffix：保留left累计、empty-context payload复用和所有cutoff规则；每次真实payload score对left/right各直接调用一次相同profiler-aware scorer，source=.suffix，mode为实际RFC mode。
- cluster：恢复per-mode memo，lookup miss才调用同一个pure scorer，source=.cluster；map score cache hit仍跳过它原来跳过的评分工作。

ordinary specialization没有clock/Profile更新。normal/reference suffix可保留原sparse-only右侧缓冲行为；profiled直接suffix helper可将scratch全zero再写active entries，以明确其输入初始化。它不建立或读取full256 memo key。两者使用同一固定support和相同tree score，零填非active项不会改变结果。严禁将未初始化非active项送入hash/memeql或新的诊断扫描。

原deterministic alphabet/lengths/prefix计分、allocator闭包、nullable候选和错误传播保持。直接评分失败就按原try传播；cluster miss评分失败不put；原128slot覆盖与map cache发布顺序保留。现有tree/map评分调用链是fixed-stack/noheap，fallback不凭空引入新的临时allocation或OOM索引差异。

## 区分直接调用与cache miss

保留当前`tree_score_scope_counts[3]`和`tree_score_mode_counts[4][3]`，其七字段继续只描述真实memo lookup。baseline/suffix不查memo时，它们的requests/hits/misses/cold/conflict都为零，不能把直接评分伪记成cache miss。

新增最少固定统计，例如：

```text
tree_score_uncached_calls: usize
tree_score_uncached_scope_calls: [3]usize
tree_score_uncached_mode_calls: [4][3]usize
```

只在profiled直接pure score路径更新。baseline仅全局source[baseline]有计数，per-mode baseline列仍零；suffix按实际mode/source计数。`Profile.addSample`与detail输出合并这些字段，已有shape/iterations/input/active字段继续描述本次真实搜索。

完成且成功的sample应满足：

```text
tree_score_calls = tree_score_cache_misses + tree_score_uncached_calls
uncached calls = baseline direct calls + suffix direct calls
baseline direct calls = 1（有效Analysis）
suffix direct calls = 2 * suffix_payload_scores
cache requests = cache hits + cache misses
```

全部simple/complex、active buckets和small-Huffman/prefix计数继续覆盖所有真实tree score调用。失败sample保留其error与部分统计，不套用成功完成的恒等式。现有`cache_misses == tree_score_calls`测试必须更新为上述分解，不能为迎合旧测试而漏计baseline/suffix。

per-mode cluster memo的所有entries都来自同一mode的cluster scope，因此实际cross_scope_hits/cross_mode_hits为零。可以停止共享-only origin标记和origin hash读写，cluster profile不需第三次hash去判断已由生命周期确定的来源。原cache.get的full histogram/hash/equality和cold/conflict分类保持；不在这个fallback里叠加大范围zero-accounting优化，也不承诺普通ELF所有counter inc会DCE。

## 保留recent/context诊断并避免重复时间

保留父任务已接的recent与context子scope，以及 [固定8条ContextDetail](/home/passchaos/project-z/vort-brotli-context-cache/src/br/encoder/quality_profile.zig:123) 的event_id、origin、variant、command_count、实际Profile和truncation行为。数据满容量只截断报告，不改变codec选择。真实context helper继续返回这一调用中产生的Proposals，recent command plan与context search只执行原本的一次。

时间定义继续保持：

```text
stageNs = analysis + baseline + suffix + sparse + cluster
mode_ns = 各mode inclusive观察值，单独显示，不加进stageNs
treeScoreStageNs ⊆ baseline + suffix + cluster_score
clusterStageNs ⊆ cluster
```

tree/small-Huffman/complex-prefix是嵌套分解，不再加到其parent stage形成第二份总时间。baseline/suffix改为true直接scorer后，其nested tree时间与真实外层scope一致。recent/context子scope继续属于父quality事件树；事件inclusive/exclusive算法不因cache回退重写。

如果counter含义变化，detail/schema说明明确标注policy为per-mode cluster memo与新增uncached分解，不把旧shared smoke计数套到fallback。旧field保持可读取，并保存当前shared候选记录以便比较。

## 实施与接受条件

若父任务决定回退，最小修改涉及literal-context split/profile及共享-only cache metadata；br root/quality-profile的真实子scope和actual-return plumbing保持。新计数只增加固定profile数组，不添加user option、runtime memo开关、无限日志或新heap状态。

1. default/reference/profiled的全部Proposals字段逐项一致，所有ForMode/prefix/chooseUpTo/chooseSuffix行为与旧策略一致，输入/commands保持不变。
2. 新direct scorer的bit cost与原treeBitCostWithSupport完全相同；scope计数覆盖baseline/suffix，cache统计仅cluster，成功sample满足上述分解。low-support/high-symbol fixtures不得读非active undefined数据。
3. 维持原tree/key碰撞、cache失败不发布、allocator/error与cleanup、iteration/seed/candidate thresholds等测试。将本轮profile统计测试更新为直接/缓存分离，保留近期actual-detail与bounded-capacity合同测试。
4. 默认quiet与公开profiled都运行旧policy，验证实际writer路径wire identity一致；不只比较selector返回值，不把shared实验profile作为默认结果。
5. 父任务统一构建/检查ELF及公共对照：确认default无跨scope/mode共享memo，profile真实记录direct baseline/suffix，而非仅移除报告字段。保存双方source/exe/settings/input/wire身份。性能接受结论由父任务作出，不以cache hits或源码加法数量推导。

本轮读取的候选源码SHA保持：split `5e0f139d1a30601e5824bdaade4c23fad1af4de0632fdfe6ed31e79f68a8c458`，profile `b6292a1e6427e65a7aeed3433821384cbf57c7400cb89e3ee1a9195b68f770d3`，cache `f2b16b331850d6bebcce486a75327648aafd8513b47cdffc7313ad42fa6497b6`。本文件仅供后续条件性实施审核；当前没有执行回退。
