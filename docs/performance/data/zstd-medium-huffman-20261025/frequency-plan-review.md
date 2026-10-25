# Exact last-frequency plan cache: independent static review

只读审查工作树 `/home/passchaos/project-z/vort-zstd-duplicate-profile`。
审查完成的 cache 源码 SHA：
`febc4c652af67f6a0a0f3fdd5a4c7f38e18612a6373ed1eced3347022b4294fa`。
本次没有编译、编码、benchmark、测试、源码编辑或 Git 操作。

结论：**没有发现新频率计划缓存的重大正确性、null/error 发布、四流绑定或
对象生命周期问题。** 公开 profiler 的独立 accounting 分支在 product 的
comptimefalse 路径消除，但 Cache Work 计数仍在源码中无条件增加；不能由静态
审查宣称全部 profile overhead 为零。

## 发布不变量

`single_cost_cache.zig:48..51` 保存两个不同层次的状态：

- `tree_entry`：完整 tree key 与成功返回的 `?usize serialized_len`。
- `last_frequencies`：精确256项u32频率，只绑定到当前成功 tree_entry。

`planEntry:120..136` 仅在 tree_entry 和 last_frequencies 都存在、完整频率向量
逐项相等时命中。它没有用literal总数、hash、最大frequency或active count替代
完整比较，所以不存在这些简化 key 的碰撞。offset/match_len不进入key，因为它们
只影响后续sequence costs，仍由原Codec规则重算。

miss之后的顺序正确：

1. 记录一次真实 builder attempt。
2. `Codec.planFromFrequencies` 返回null时立即返回，未更新tree/frequency绑定。
3. `try cachedTreeLen(&plan)`：失败时错误传播，旧key/value/frequencies保留。
4. 只有成功之后才复制整个frequency vector，返回当前tree_entry的借用指针。

`cachedTreeLen:140..154` 新key成功时先发布匹配tree key/value，并清空旧
last_frequencies；随后planEntry重新绑定新frequency。即使其他内部测试直接调用
cachedTreeLen，也不会把旧frequency key错误绑定到新tree。相同tree、不同频率的
hit则正确保留tree结果，并在planEntry末尾改绑该频率。

返回null区分清楚：plan不存在时planEntry返回null，不缓存；plan存在但成功的
tree_len为null时tree_entry存在，last_frequencies也能绑定，之后的samefrequency
查询会返回这个成功null并走相同raw成本回退。没有将错误转换为null。

`literalSectionLen:104..106` 返回的entry指向Cache内部optional payload，使用期间
streamsLen只读key并更新work；没有移动或替换tree_entry，也未把该指针长期保存。
Cache仅借用一个immutable block，新key/vector按值保存，无堆分配和可移动self
地址依赖。整个Cache搬移后，下一次查询重新获取内部指针即可。

不变量要求Codec的plan builder/tree estimator对相同频率与编译配置确定。
实际CostCodec在zstd.zig:31069..31077从fresh plan构造并finalize，满足该范围。
不存在运行时dictionary、prior table或mutable profile参数混入该key的调用。

## 四流仍按当前分区精确定价

频率计划命中仅复用tree key与其serialized_len。`literalSectionLen:94..99` 每次
先更新CutHistogram并取得当前regenerated长度；`streamsLen:159..174` 每次使用
**当前**stream_frequencies与entry.bit_counts做乘积，而非复用上次stream字节数。

CutHistogram以整个block的byte-zero prefix/tail语义工作：
`block[0..prefix_len] ++ block[tail_start..]`。没有因finder start_min非零改变旧scorer。
`cut_histogram.zig:95..112` 保留≤1023单流、≥1024四流、ceil(length/4)分段和物理
prefix/tail映射；totalFrequencies:63..67只供共享tree计划。

stream成本保留单个end bit与padding：`(stream_bits+8)/8`等于
ceil((stream_bits+1)/8)。四流的6字节jump table仍在total中；数值乘积/加法检查
保持。当前Cache最大block128KiB，四流各至多32768个literal，11bit最长code时
每流字节数也远低于u16上限；没有因缓存跳过边界检查。

独立 `frequencyPlans` oracle 的反例覆盖正确：2050B block，cuts(511,513)与
(513,515)产生相同总frequency，但stream0/1交换不同code-width的literal，使
stream_bytes和literal成本不同。tests:147..178独立拼接真实literal数组、按byte
统计与定价，不使用Cache的ranges/frequency作为oracle；189..242检查只计划一次
而stream products继续增加，并覆盖frequency替换/回访和非法cut后的恢复。
这些是已读取的测试设计；本审查没有执行它们。

## 诊断和 product 路径边界

新diagnostic入口 `zstd.zig:19491..19501` 仅允许未索引范围65536…131072，非法
尺寸在profile重置前拒绝，合法工作调用Profiled(true,true)。它测的是一个特定
multi_duplicate候选，不是完整level3 policy，也不提供正常encoding选项的新knob。

正常调用 `zstd.zig:23257..23258` 使用comptime profile_work=false，并传null
profile。因此外层finder_calls/selected_matches与defer发布分支
(:23269..23276/23282/23294)在该实例化中消除；可以静态保证正常路径不构建
NativeMultiDuplicateProfile对象、不执行这些profile指针分支。

**不能扩大为所有统计没有CPU成本：** Cache Work及CutHistogram计数仍在源码中
无条件更新，包括cost_queries、huffman_plans、huffman_plan_cache_hits、tree work
和stream_symbol_products。优化器可能消除部分未读取字段，但该结论需要实际
目标代码或quiet测量，不能从comptimefalse替它证明。

`multi_duplicate_profile.zig:10` 新增cache_state_bytes；defer在cache实际存在时
填 `@sizeOf(SingleLiteralCostCache)`。它描述固定state字节数，不是峰值RSS、总栈
或请求堆。RLE早退没有cache工作，profile仍为零，不能填虚构的缓存使用。
新lastfrequency字段是1024B向量加optional表示/对齐，实际完整大小以工具记录为准，
不在本只读审查推算ABI size。它是fixed state，未新增heap请求。

## 错误与工作计数解释

工作计数是attempts，不是只计成功计划：planFromFrequencies返回null仍增加
huffman_plans；treeLen出错增加tree_serializations而不publish。不能在任意mock
或malformed场景下假定huffman_plans总等于tree_serializations+tree_cache_hits，
因为builder-null没有tree lookup。实际diagnosticfixture的该等式是其数据条件。
frequency hits单独记huffman_plan_cache_hits，不再重复增加tree_cache_hits；这使
两个缓存层的收益可以区分。

同模块mock tests:262..319检查完整vector变化、仅last entry、成功null、重复错误
保旧绑定及builder-null不publish。现有直接tree tests也保留key/metadata/null/error。
没有发现缺失的生产依赖或错误发布分支。

下一步由父任务继续已有专项与安静复测即可；本审查没有制造新的编码/计时负载，
没有重复旧基线，也没有对加速幅度或当前time占比作判断。

审查时间：2026-10-25 13:20（Asia/Shanghai）。
