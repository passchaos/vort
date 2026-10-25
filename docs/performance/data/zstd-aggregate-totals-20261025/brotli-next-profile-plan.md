# 下一项 bounded 工作：完整 q8 候选成本归因

结论：先给**实际公开 q8 pipeline**增加一个按候选归因的诊断入口，只测冻结
Mozilla64KiB，并用 source64KiB 作控制样本。优先区分 bounded optimal 搜索与
重复 context/split wire 构造的成本。不要用现有 legacy fast stage 工具的结果
代表 q8，也不要先降低 q8 的候选、深度或 split policy。

本文件是对主树 `6b262754` 的只读静态分析。没有编译、运行 profile、计时、
修改源码或 Git。下列性能数值引用现有文档的 `d4297483` 首轮基线，不是新测量。

## 已有证据与能力边界

`docs/performance/current-codec-encode-x86-20261025.md` 记录：14 个真实64KiB
输入，Vort q8 / reference q8 的中位吞吐比几何平均0.028209652，大小领先9/14，
总字节288091 / 296445。Mozilla64KiB 是有用的慢样本：96.226670ms 对
1.543179ms，大小14216 / 13646。这个输入既慢又没有大小优势，适合先做
候选成本/收益账本。

调用是 `br.encodePlannedStreamWithOptionsAlloc(a,input,.{.quality=8,.mode=.generic})`
的 native preset，不是 `hq!=null` 的另一条 explicit HQ pipeline。
`src/br.zig:4569` 分流到 `encodePlannedStreamQualityWithOptionsAlloc`；没有更换
质量档位、输入块、窗口或命令模型的理由。

q8 调度在 `src/br/encoder/quality_schedule.zig:233` 和 `:276`：

- ratio family；lazy max_chain128、nice_len192、min_gain1。
- optimal max_chain128、nice_len192、max_candidates64，最大输入64KiB；
  entropy_feedback=false，command-state 最大输入默认为0。
- 默认 wire window16。lazy search window为min(input,65520)；optimal另取
  min(input,wire-window,lz77.default_window_len)，不能将两者当成相同搜索集合。
- recent distances、literal contexts/cluster contexts、literal/command/distance
  split、adaptive literal 和 adaptive distance启用；adaptive command、joint
  contexts、entropy反馈及 command-state beam 没有在 q8 启用。

所以64KiB q8包含一次lazy proposal和一次bounded fixed-cost optimal proposal，
各自以完整Brotli wire仲裁。它不是穷举所有长度、所有offset状态和所有
entropy-context/split组合的全局最优算法；公开质量/字典/流式API覆盖与这种
算法最优性是不同问题。也不能把q8指向q10/q11的有限command-state beam。

本地 `/home/passchaos/Work/brotli/c/enc/encode.c:1129` 只在q10/q11进入
Zopfli/HQ-Zopfli；reference q8使用普通backward references。
`quality.h:175` 的q8 hasher选择与lgwin/size_hint有关，reference本轮lgwin22，
Vort默认16。因此同档位号不意味着相同算法、搜索窗口或候选工作。

## 静态调用链与需要测量的热点

`src/br.zig:5053` 的一次完整q8编码依次执行：

1. lazyGreedyPlanAlloc → command_plan.buildAlloc → encodeLazyCommandPlanAlloc。
2. 从lazy commands计算distance参数候选并作完整wire仲裁。
3. encodeQualityOptimalCandidateAlloc (`:5253`) → lz77.optimalPlanAlloc →
   command_plan.buildAlloc → 再一次encodeLazyCommandPlanAlloc。
4. 用最终完整wire与stored bound比较。

默认window16排除long-distance分支；64KiB排除≤256/4096的static-dictionary
分支；q8排除q10+ record-optimal分支、entropy-feedback第二遍及font分支。
不要把这些没有进入的工作解释为本轮慢因。

**第一可单独测热点是同一命令计划的 wire candidate fan-out**：
`encodePreferredCommandPlanAlloc:10027` 先发primary context，然后发去重后的
suffix/up-to-16/full context候选，必要时再发plain baseline。
`encodeEntropySplitCandidateAlloc:10178` 计算literal/command/distance proposals，
并逐一物化可用的two/three/clustered/alternating/reused/four/dynamic候选、
adaptive候选及部分组合，再保留完整wire最小者。lazy与optimal两套计划都
可能走这条路径。每次wire构造在`:10975`重新计频、建alphabet/code lengths、
写header和payload。只有实际调用数、字节收益和stage时间能判断它是否占主导；
源码分支多不等于每个分支都在Mozilla执行。

**需要同时留一个竞争解释**：`src/lz77.zig:1559` 的reverse DP逐位置遍历
hash chain、prefix guard、matchLength和length-choice扩展。它已有精确prefix
cost bound及profile统计，不能把每条chain都当成一次完整extension。q8预算
128/192/64与legacy ratio profile的512/258/128不同。

`src/br.zig:6092` 的distance search已将语义distance压缩计频，再在
distance_parameter_search.selectAlloc估价多种形状；随后只编码基线和一个
有利替代。**不是64次完整wire生成**，不能以这个错误假设优先改它。

## 现有工具为何不够

| 工具/入口 | 实际测量范围 | 对q8的限制 |
| --- | --- | --- |
| planned_stage_profile.zig | 三个小内置样本；legacy `brEncodePlannedStreamAllocWithStatsTimed` | 无quality参数，无64KiB Mozilla，没有q8完整候选链 |
| planned_stage_bench.zig | legacy hash-greedy parser和legacy fast complete encoding | 只分parser/full，不是q8 |
| ratio_stage_profile.zig | legacy `.level=.ratio`，source4/16/32KiB及records fixture | 不同budget；输出虽然有optimal/wire timing，也不能代表q8 |
| quality_command_state_profile.zig | 参数只允许q10/q11；独立command-state候选 | q8不进入这条路径 |
| lz77.optimalPlanAllocProfiled | 与普通optimal同core的独立profile specialization | 可用，但必须喂实际q8窗口和128/192/64预算 |
| planned_encode_bench.zig | 公开q8、实际输入、全部raw rounds和wire SHA | 只有完整编码时间，没有candidate归因 |

现有前几项stage工具仍经full `vort` root (`build.zig:3388/3510`) 构建。新工具应
使用已经证明可行的私有 `vort_br` module，仅Br record object，避免无关codec
编译闭包；不发布新package入口。

## 唯一建议的下一 bounded increment

做一个**q8完整候选账本**，先不改任何选优规则。建议所有者清晰的文件范围：

- `src/br/encoder/quality_profile.zig`：小型diag结构，记录stage、plan来源、
  实际candidate kind/count、输入/命令/literal数量、wire长度、selected与收益。
- `src/br.zig`：让q8共用相同实现，只在独立comptime-profile specialization
  给`:5053/:5253/:10027/:10178/:10975`的阶段边界计时/记调用。正常public路径
  profile=false，不读时钟，不观察统计。不要复制另一份近似q8算法。
- `tools/br/quality_stage_profile.zig`：读取固定路径、q8/generic、window默认16，
  输出JSON候选账本、input/wire SHA与provenance；共享模块仅用vort_br。
- `src/tests/br_quality_profile_contracts.zig`：与普通公开q8逐字节比较，覆盖
  empty/tiny/64KiB、q8边界、OOM/总预算与所有权。build只挂窄工具和测试。

每次profile先调用普通公开q8保存完整wire，再要求profile返回同一wire。
记录lazy与optimal的每个候选尝试及最终赢家，不能只保留最后赢家stats。
先给coarse阶段时钟，不给每次hash/query/matchLength计时。若optimal阶段
占主导，再用现有profiled core核对chain/prefix/extension工作；两种诊断的
开销与普通无观察版本分别报告，防止重演“profile计数代表production”的问题。

验收目标是把完整q8时间归到lazy-plan/command、preferred-context、split-plan、
各wire-emission、distance-estimate、optimal-plan/command和selection；保留
unaccounted时间，要求至少90%的外层时间有不重复记账的对应阶段。仪器改动
先在frozen14 inputs全部wire相同后，才解释Mozilla与source控制样本。

后续获准实施和quiet时的命令模板（**尚未执行，目标/工具尚需实现**）：

```sh
taskset -c 13-15 zig build -Doptimize=ReleaseFast -Dcpu=native -j2 \
  build-br-quality-stage-profile
taskset -c 8 zig-out/bin/vort-br-quality-stage-profile \
  --quality 8 --mode generic --rounds 5 --iterations 1 \
  --path /tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation/silesia-mozilla-65536.bin \
  --path /tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation/brotli-source-65536.bin \
  --json /tmp/vort-br-q8-profile-20261025/candidates.json
```

若账本确认重复wire准备占主要时间，第一项保持wire的优化才是**单次调用、
同一不可变命令计划的准备数据复用**：缓存literal positions/bytes及在相同
recent-distance、distance-parameter、起始ring/输出位置/字典/window条件下的
command/distance派生；context/split频率仍按各候选重建。新模块可放
`src/br/encoder/prepared_command_wire.zig`。不能跨lazy/optimal/short-copy变体
复用，也不能只按slice指针作为key。保留原candidate顺序、严格小于的tie规则
和完整wire比较，用参考重建路径做differential、OOM和预算测试。

这只是明确的、待profile支持的优化选择；现在不切候选、不减质量预算、
不声称它会提升多少。若账本否定wire准备为主因，就停止这项复用实现，
带着实际stage证据再确定下一块。Brotli的系统性q8瓶颈应优先获得这个账本，
不应由Zstd约2%的局部anchor改善决定其工作方向。
